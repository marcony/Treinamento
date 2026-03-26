public with sharing class LogAnalyzerDTO {
    public class AnalyzeRequest {
        @AuraEnabled public String rawLog;
        @AuraEnabled public Integer maxIssues;
    }

    public class AnalyzeResponse {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String summary;
        @AuraEnabled public Integer totalIssues;
        @AuraEnabled public List<Issue> issues;
        @AuraEnabled public Result aiResult;
    }

    public class Issue {
        @AuraEnabled public String severity;
        @AuraEnabled public String code;
        @AuraEnabled public String message;
        @AuraEnabled public Integer lineNumber;
    }

    public class LogItem {
        @AuraEnabled public Id id;
        @AuraEnabled public String operation;
        @AuraEnabled public String status;
        @AuraEnabled public Integer durationMs;
        @AuraEnabled public Integer logLength;
        @AuraEnabled public Datetime startTime;
    }

    public class Result {
        @AuraEnabled public String rootCause;
        @AuraEnabled public List<String> evidence;
        @AuraEnabled public List<String> fixSteps;
        @AuraEnabled public String code;
        @AuraEnabled public List<String> prevention;
    }
}
