public with sharing class ToolingLogService {
    @TestVisible
    private static final Integer DEFAULT_LIMIT = 20;
    @TestVisible
    private static final Integer DEFAULT_MAX_CHARS = 200000;
    @TestVisible
    private static final String API_VERSION = '63.0';

    public interface LogProvider {
        List<ApexLog> fetch(Integer limitSize);
    }

    private class DefaultLogProvider implements LogProvider {
        public List<ApexLog> fetch(Integer limitSize) {
            return [
                SELECT Id, Operation, Status, DurationMilliseconds, LogLength, StartTime
                FROM ApexLog
                ORDER BY StartTime DESC
                LIMIT :limitSize
            ];
        }
    }

    @TestVisible
    private static LogProvider provider = new DefaultLogProvider();

    @TestVisible
    static void setProvider(LogProvider testProvider) {
        provider = (testProvider == null) ? new DefaultLogProvider() : testProvider;
    }

    public static List<LogAnalyzerDTO.LogItem> getRecentLogs(Integer limitSize) {
        Integer safeLimit = (limitSize == null || limitSize <= 0) ? DEFAULT_LIMIT : limitSize;
        List<ApexLog> logs = provider.fetch(safeLimit);
        List<LogAnalyzerDTO.LogItem> items = new List<LogAnalyzerDTO.LogItem>();

        for (ApexLog logItem : logs) {
            LogAnalyzerDTO.LogItem dto = new LogAnalyzerDTO.LogItem();
            dto.id = logItem.Id;
            dto.operation = logItem.Operation;
            dto.status = logItem.Status;
            dto.durationMs = logItem.DurationMilliseconds;
            dto.logLength = logItem.LogLength;
            dto.startTime = logItem.StartTime;
            items.add(dto);
        }

        return items;
    }

    public static String getBody(Id logId, Integer maxChars) {
        validateLogId(logId);

        Integer safeMaxChars = (maxChars == null || maxChars <= 0) ? DEFAULT_MAX_CHARS : maxChars;

        HttpRequest req = new HttpRequest();
        req.setMethod('GET');
        req.setTimeout(120000);
        req.setEndpoint(buildLogBodyEndpoint(logId));
        String sessionId = UserInfo.getSessionId();
        if (String.isBlank(sessionId)) {
            throw new AuraHandledException('Sessao expirada ou sem permissao para acessar o log.');
        }
        req.setHeader('Authorization', 'Bearer ' + sessionId);

        HttpResponse res;
        try {
            res = new Http().send(req);
        } catch (Exception ex) {
            throw new AuraHandledException('Falha ao buscar o corpo do log. Tente novamente em instantes.');
        }
        Integer statusCode = res.getStatusCode();

        if (statusCode == 200) {
            return truncateToLastChars(res.getBody(), safeMaxChars);
        }
        if (statusCode == 401 || statusCode == 403) {
            throw new AuraHandledException('Sessao expirada ou sem permissao para acessar o log.');
        }
        if (statusCode == 404) {
            throw new AuraHandledException('Log nao encontrado para o Id informado.');
        }

        throw new AuraHandledException('Falha ao buscar o corpo do log. Tente novamente em instantes.');
    }

    @TestVisible
    private static String buildLogBodyEndpoint(Id logId) {
        return URL.getOrgDomainUrl().toExternalForm()
            + '/services/data/v'
            + API_VERSION
            + '/tooling/sobjects/ApexLog/'
            + String.valueOf(logId)
            + '/Body/';
    }

    @TestVisible
    private static void validateLogId(Id logId) {
        if (logId == null) {
            throw new AuraHandledException('Informe um logId valido.');
        }

        String idValue = String.valueOf(logId);
        if (idValue.length() != 15 && idValue.length() != 18) {
            throw new AuraHandledException('Formato de logId invalido.');
        }

        String apexLogPrefix = ApexLog.SObjectType.getDescribe().getKeyPrefix();
        if (!idValue.startsWith(apexLogPrefix)) {
            throw new AuraHandledException('Formato de logId invalido para ApexLog.');
        }
    }

    @TestVisible
    private static String truncateToLastChars(String value, Integer maxChars) {
        if (String.isBlank(value) || maxChars == null || maxChars <= 0 || value.length() <= maxChars) {
            return value;
        }
        return value.substring(value.length() - maxChars);
    }
}
