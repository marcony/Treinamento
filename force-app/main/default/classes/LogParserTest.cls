@IsTest
private class LogParserTest {
    @IsTest
    static void shouldParseIssuesFromRawLog() {
        String rawLog = String.join(new List<String>{
            '10:00:00.0 (100)|METHOD_ENTRY|[1]|',
            '10:00:00.1 (200)|EXCEPTION_THROWN|[5]|System.NullPointerException',
            '10:00:00.2 (300)|FATAL_ERROR|System.DmlException',
            '10:00:00.3 (400)|USER_DEBUG|[8]|DEBUG|ok'
        }, '\n');

        List<LogAnalyzerDTO.Issue> issues = LogParser.parseIssues(rawLog, 10);

        System.assertEquals(2, issues.size());
        System.assertEquals('MEDIUM', issues[0].severity);
        System.assertEquals('FATAL_ERROR', issues[1].code);
    }

    @IsTest
    static void shouldRespectIssueLimit() {
        String rawLog = String.join(new List<String>{
            'A|EXCEPTION_THROWN|',
            'B|FATAL_ERROR|',
            'C|ERROR|'
        }, '\n');

        List<LogAnalyzerDTO.Issue> issues = LogParser.parseIssues(rawLog, 1);

        System.assertEquals(1, issues.size());
    }

    @IsTest
    static void shouldBuildSummaryWithExpectedContract() {
        String rawLog = String.join(new List<String>{
            '12:00:00.000 (1)|SOQL_EXECUTE_BEGIN|[3]|Aggregations:0|SELECT Id FROM Account',
            '12:00:00.010 (2)|SOQL_EXECUTE_BEGIN|[4]|SELECT Id FROM Contact',
            '12:00:00.020 (3)|EXCEPTION_THROWN|[8]|System.NullPointerException: Attempt to de-reference a null object',
            '12:00:00.030 (4)|DML_BEGIN|[9]|Op:Insert|Type:Account|Rows:1',
            '12:00:00.040 (5)|CUMULATIVE_LIMIT_USAGE',
            '  Number of SOQL queries: 22 out of 100',
            '  Number of DML statements: 3 out of 150',
            '  Maximum CPU time: 9000 out of 10000'
        }, '\n');

        String summaryJson = LogParser.summarize(rawLog);
        LogParser.LogSummary summary = (LogParser.LogSummary) JSON.deserialize(summaryJson, LogParser.LogSummary.class);

        System.assertEquals('System.NullPointerException', summary.exceptionType);
        System.assert(summary.message.contains('null object'));
        System.assert(summary.evidence.size() >= 1);
        System.assertEquals(22, summary.limits.soql);
        System.assertEquals(3, summary.limits.dml);
        System.assertEquals(9000, summary.limits.cpuMs);
        System.assert(summary.signals.contains('Possible N+1 query pattern'));
        System.assert(summary.signals.contains('CPU risk'));
        System.assert(summary.signals.contains('Null reference before DML'));
    }
}
