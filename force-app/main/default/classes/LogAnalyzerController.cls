public with sharing class LogAnalyzerController {
    @AuraEnabled(cacheable=true)
    public static List<LogAnalyzerDTO.LogItem> getRecentLogs(Integer limitSize) {
        return ToolingLogService.getRecentLogs(limitSize);
    }

    @AuraEnabled(cacheable=false)
    public static LogAnalyzerDTO.Result analyzeLog(String logId) {
        try {
            String rawLog = ToolingLogService.getBody((Id) logId, 200000);
            String summaryJson = LogParser.summarize(rawLog);
            String maskedSummaryJson = AIAnalysisService.maskSensitiveData(summaryJson);
            return AIAnalysisService.analyze(maskedSummaryJson);
        } catch (AuraHandledException ex) {
            throw ex;
        } catch (Exception ex) {
            throw new AuraHandledException('Nao foi possivel analisar o log informado. Tente novamente.');
        }
    }
}
