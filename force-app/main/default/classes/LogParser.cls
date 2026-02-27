public with sharing class LogParser {
    @TestVisible
    private static final Integer DEFAULT_MAX_ISSUES = 50;
    @TestVisible
    private static final Integer EVIDENCE_RADIUS = 10;
    @TestVisible
    private static final Integer MAX_EVIDENCE_LINES = 30;

    public class LogSummary {
        public String exceptionType;
        public String message;
        public List<String> evidence;
        public Limits limits;
        public List<String> signals;
    }

    public class Limits {
        public Integer soql;
        public Integer dml;
        public Integer cpuMs;
    }

    private class ExceptionInfo {
        String exceptionType;
        String message;
    }

    public static List<String> splitLines(String rawLog) {
        if (String.isBlank(rawLog)) {
            return new List<String>();
        }
        return rawLog.split('\\r?\\n');
    }

    public static String summarize(String rawLog) {
        return JSON.serialize(summarizeAsObject(rawLog));
    }

    @TestVisible
    static LogSummary summarizeAsObject(String rawLog) {
        List<String> lines = splitLines(rawLog);
        LogSummary summary = new LogSummary();
        summary.exceptionType = '';
        summary.message = '';
        summary.evidence = new List<String>();
        summary.limits = new Limits();
        summary.limits.soql = 0;
        summary.limits.dml = 0;
        summary.limits.cpuMs = 0;
        summary.signals = new List<String>();

        Integer failureIndex = -1;
        Integer firstDmlIndex = -1;
        Integer soqlExecuteCount = 0;
        Integer dmlBeginCount = 0;

        for (Integer i = 0; i < lines.size(); i++) {
            String line = lines[i];
            String upper = line != null ? line.toUpperCase() : '';

            if (firstDmlIndex == -1 && upper.contains('|DML_BEGIN|')) {
                firstDmlIndex = i;
            }
            if (upper.contains('|SOQL_EXECUTE_BEGIN|')) {
                soqlExecuteCount++;
            }
            if (upper.contains('|DML_BEGIN|')) {
                dmlBeginCount++;
            }

            if (failureIndex == -1 && (upper.contains('FATAL_ERROR') || upper.contains('EXCEPTION_THROWN'))) {
                failureIndex = i;
                ExceptionInfo info = parseException(line);
                summary.exceptionType = info.exceptionType;
                summary.message = info.message;
            }

            collectLimits(line, summary.limits);
        }

        summary.evidence = buildEvidence(lines, failureIndex);

        if (soqlExecuteCount >= 20) {
            summary.signals.add('Possible N+1 query pattern');
        }
        if (summary.limits.cpuMs >= 8000) {
            summary.signals.add('CPU risk');
        }

        Boolean nullRef = (summary.exceptionType != null && summary.exceptionType.toUpperCase().contains('NULLPOINTER'))
            || (summary.message != null && summary.message.toUpperCase().contains('NULL'));
        if (nullRef && firstDmlIndex > failureIndex && dmlBeginCount > 0) {
            summary.signals.add('Null reference before DML');
        }

        return summary;
    }

    public static List<LogAnalyzerDTO.Issue> parseIssues(String rawLog, Integer maxIssues) {
        Integer limitSize = (maxIssues == null || maxIssues <= 0) ? DEFAULT_MAX_ISSUES : maxIssues;
        List<LogAnalyzerDTO.Issue> issues = new List<LogAnalyzerDTO.Issue>();
        List<String> lines = splitLines(rawLog);

        for (Integer i = 0; i < lines.size() && issues.size() < limitSize; i++) {
            String line = lines[i];
            if (isIssueLine(line)) {
                issues.add(toIssue(line, i + 1));
            }
        }

        return issues;
    }

    private static Boolean isIssueLine(String line) {
        if (String.isBlank(line)) {
            return false;
        }

        String normalized = line.toUpperCase();
        return normalized.contains('EXCEPTION_THROWN')
            || normalized.contains('FATAL_ERROR')
            || normalized.contains('|ERROR|');
    }

    private static LogAnalyzerDTO.Issue toIssue(String line, Integer lineNumber) {
        LogAnalyzerDTO.Issue issue = new LogAnalyzerDTO.Issue();
        issue.lineNumber = lineNumber;
        issue.message = line;

        String normalized = line.toUpperCase();
        if (normalized.contains('FATAL_ERROR')) {
            issue.severity = 'HIGH';
            issue.code = 'FATAL_ERROR';
        } else if (normalized.contains('EXCEPTION_THROWN')) {
            issue.severity = 'MEDIUM';
            issue.code = 'EXCEPTION_THROWN';
        } else {
            issue.severity = 'LOW';
            issue.code = 'ERROR';
        }

        return issue;
    }

    private static ExceptionInfo parseException(String line) {
        ExceptionInfo info = new ExceptionInfo();
        info.exceptionType = '';
        info.message = line;

        if (String.isBlank(line)) {
            return info;
        }

        Matcher matcher = Pattern.compile('([A-Za-z0-9_$.]*Exception)\\s*:?\\s*(.*)$').matcher(line);
        if (matcher.find()) {
            info.exceptionType = matcher.group(1);
            info.message = matcher.group(2);
            if (String.isBlank(info.message)) {
                info.message = line;
            }
        }

        return info;
    }

    private static List<String> buildEvidence(List<String> lines, Integer failureIndex) {
        List<String> evidence = new List<String>();
        if (lines.isEmpty()) {
            return evidence;
        }

        Integer center = (failureIndex >= 0) ? failureIndex : 0;
        Integer start = Math.max(0, center - EVIDENCE_RADIUS);
        Integer end = Math.min(lines.size() - 1, center + EVIDENCE_RADIUS);

        for (Integer i = start; i <= end; i++) {
            evidence.add(lines[i]);
        }

        while (evidence.size() > MAX_EVIDENCE_LINES) {
            evidence.remove(0);
        }

        return evidence;
    }

    private static void collectLimits(String line, Limits limits) {
        if (String.isBlank(line)) {
            return;
        }

        String upper = line.toUpperCase();
        if (limits.soql == 0 && upper.contains('SOQL QUERIES')) {
            limits.soql = extractNumericAfterColon(line);
        }
        if (limits.dml == 0 && upper.contains('DML STATEMENTS')) {
            limits.dml = extractNumericAfterColon(line);
        }
        if (limits.cpuMs == 0 && upper.contains('CPU TIME')) {
            limits.cpuMs = extractNumericAfterColon(line);
        }
    }

    private static Integer extractNumericAfterColon(String line) {
        if (String.isBlank(line)) {
            return 0;
        }

        String target = line;
        Integer colonIndex = line.indexOf(':');
        if (colonIndex >= 0 && colonIndex < line.length() - 1) {
            target = line.substring(colonIndex + 1);
        }

        Matcher matcher = Pattern.compile('(\\d+)').matcher(target);
        if (matcher.find()) {
            return Integer.valueOf(matcher.group(1));
        }
        return 0;
    }
}
