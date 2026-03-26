public with sharing class AIAnalysisService {
    @TestVisible
    private static Boolean useExternalLlm = false;
    private static final String MASKED_EMAIL = '[MASKED_EMAIL]';
    private static final String MASKED_TOKEN = '[MASKED_TOKEN]';
    private static final String MASKED_URL = '[MASKED_URL]';

    public static LogAnalyzerDTO.Result analyze(String logSummaryJson) {
        if (useExternalLlm) {
            return callExternalLLM(logSummaryJson);
        }
        return buildStubResult(logSummaryJson);
    }

    public static String maskSensitiveData(String input) {
        if (String.isBlank(input)) {
            return input;
        }

        String masked = input;
        // E-mails
        masked = masked.replaceAll(
            '(?i)\\b[a-z0-9._%+\\-]+@[a-z0-9.\\-]+\\.[a-z]{2,}\\b',
            MASKED_EMAIL
        );
        // Tokens comuns (Bearer e access_token)
        masked = masked.replaceAll(
            '(?i)(bearer\\s+)[a-z0-9\\-._~+/]+=*',
            '$1' + MASKED_TOKEN
        );
        masked = masked.replaceAll(
            '(?i)(access[_-]?token\\s*[=:]\\s*)[a-z0-9\\-._~+/]+=*',
            '$1' + MASKED_TOKEN
        );
        // Endpoints/URLs
        masked = masked.replaceAll(
            '(?i)https?://[^\\s\"\\\']+',
            MASKED_URL
        );

        return masked;
    }

    public static String buildSummary(List<LogAnalyzerDTO.Issue> issues) {
        if (issues == null || issues.isEmpty()) {
            return 'Nenhum problema encontrado no log analisado.';
        }

        Integer high = 0;
        Integer medium = 0;
        Integer low = 0;

        for (LogAnalyzerDTO.Issue issue : issues) {
            if (issue == null || String.isBlank(issue.severity)) {
                continue;
            }

            if (issue.severity == 'HIGH') {
                high++;
            } else if (issue.severity == 'MEDIUM') {
                medium++;
            } else {
                low++;
            }
        }

        return 'Foram encontrados ' + issues.size() + ' problemas (HIGH=' + high + ', MEDIUM=' + medium + ', LOW=' + low + ').';
    }

    private static LogAnalyzerDTO.Result buildStubResult(String logSummaryJson) {
        LogAnalyzerDTO.Result result = new LogAnalyzerDTO.Result();
        result.rootCause = 'Unknown failure';
        result.evidence = new List<String>();
        result.fixSteps = new List<String>();
        result.code = '';
        result.prevention = new List<String>();

        Map<String, Object> summary = parseSummary(logSummaryJson);
        String exceptionType = getString(summary, 'exceptionType');
        String message = getString(summary, 'message');
        List<String> signals = getStringList(summary, 'signals');
        List<String> evidence = getStringList(summary, 'evidence');
        if (!evidence.isEmpty()) {
            result.evidence.addAll(evidence);
        }

        if (!String.isBlank(exceptionType)) {
            result.rootCause = exceptionType + (String.isBlank(message) ? '' : ': ' + message);
        } else if (!String.isBlank(message)) {
            result.rootCause = message;
        }

        if (containsSignal(signals, 'Null reference before DML')
            || (!String.isBlank(exceptionType) && exceptionType.toUpperCase().contains('NULLPOINTER'))) {
            result.fixSteps.add('Valide objetos e campos antes de acessar propriedades em blocos com DML.');
            result.fixSteps.add('Adicione guard clauses para null antes de montar registros para insert/update.');
            result.code = 'if (record == null || record.Field__c == null) { return; }';
            result.prevention.add('Crie testes unitarios para cenarios de dados nulos antes do DML.');
        } else if (containsSignal(signals, 'Possible N+1 query pattern')) {
            result.fixSteps.add('Mova SOQL de loops para consultas em lote e use Map por Id.');
            result.fixSteps.add('Reestruture processamento para bulkification completa.');
            result.code = 'Map<Id, Account> accById = new Map<Id, Account>([SELECT Id FROM Account WHERE Id IN :ids]);';
            result.prevention.add('Revise limites de SOQL em testes de volume.');
        } else if (containsSignal(signals, 'CPU risk')) {
            result.fixSteps.add('Reduza loops aninhados e evite recalculos em cada iteracao.');
            result.fixSteps.add('Use colecoes para lookup O(1) e simplifique regras repetidas.');
            result.code = 'Set<Id> ids = new Set<Id>(); // reutilize colecoes para reduzir custo de CPU';
            result.prevention.add('Monitore CPU em logs de transacoes longas e ajuste antes de 8s.');
        } else {
            result.fixSteps.add('Revisar stack trace completo e reproduzir erro com dados controlados.');
            result.fixSteps.add('Adicionar logs de contexto para identificar etapa exata da falha.');
            result.code = '// TODO: adicionar tratamento especifico para a excecao detectada';
            result.prevention.add('Adicionar monitoramento de falhas e alertas por tipo de excecao.');
        }

        if (result.evidence.isEmpty() && !String.isBlank(message)) {
            result.evidence.add(message);
        }

        return result;
    }

    private static Boolean containsSignal(List<String> signals, String target) {
        for (String signal : signals) {
            if (signal == target) {
                return true;
            }
        }
        return false;
    }

    private static Map<String, Object> parseSummary(String logSummaryJson) {
        if (String.isBlank(logSummaryJson)) {
            return new Map<String, Object>();
        }
        Object parsed = JSON.deserializeUntyped(logSummaryJson);
        if (parsed instanceof Map<String, Object>) {
            return (Map<String, Object>) parsed;
        }
        return new Map<String, Object>();
    }

    private static String getString(Map<String, Object> data, String key) {
        if (data == null || !data.containsKey(key) || data.get(key) == null) {
            return '';
        }
        return String.valueOf(data.get(key));
    }

    private static List<String> getStringList(Map<String, Object> data, String key) {
        List<String> out = new List<String>();
        if (data == null || !data.containsKey(key) || data.get(key) == null) {
            return out;
        }
        Object raw = data.get(key);
        if (!(raw instanceof List<Object>)) {
            return out;
        }
        for (Object item : (List<Object>) raw) {
            if (item != null) {
                out.add(String.valueOf(item));
            }
        }
        return out;
    }

    @TestVisible
    private static LogAnalyzerDTO.Result callExternalLLM(String logSummaryJson) {
        // TODO: Implementar callout para Named Credential.
        // Exemplo futuro: callout:LogAnalyzerLLM/v1/analyze
        // 1) montar payload com logSummaryJson
        // 2) enviar HttpRequest com timeout configurado
        // 3) mapear JSON de resposta para LogAnalyzerDTO.Result
        return buildStubResult(logSummaryJson);
    }
}
