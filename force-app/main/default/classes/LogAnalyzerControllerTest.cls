@IsTest
private class LogAnalyzerControllerTest {
    private class LogBodyMock implements HttpCalloutMock {
        Integer statusCode;
        String responseBody;

        LogBodyMock(Integer statusCode, String responseBody) {
            this.statusCode = statusCode;
            this.responseBody = responseBody;
        }

        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(statusCode);
            res.setBody(responseBody);
            return res;
        }
    }

    private class FakeLogProvider implements ToolingLogService.LogProvider {
        public List<ApexLog> fetch(Integer limitSize) {
            return new List<ApexLog>{
                new ApexLog(
                    Id = '07L000000000002AAA',
                    Operation = 'ExecuteAnonymous',
                    Status = 'Success',
                    DurationMilliseconds = 80,
                    LogLength = 980,
                    StartTime = System.now()
                )
            };
        }
    }

    @IsTest
    static void shouldAnalyzeLogByIdAndReturnResult() {
        String rawLog = String.join(new List<String>{
            '12:00:00.010 (2)|EXCEPTION_THROWN|[8]|System.NullPointerException: Contact user@test.com endpoint https://api.example.com/v1 access_token=abc123',
            '12:00:00.030 (4)|DML_BEGIN|[9]|Op:Insert|Type:Account|Rows:1'
        }, '\n');
        Test.setMock(HttpCalloutMock.class, new LogBodyMock(200, rawLog));

        Test.startTest();
        LogAnalyzerDTO.Result result = LogAnalyzerController.analyzeLog('07L000000000002AAA');
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assert(result.rootCause.contains('System.NullPointerException'));
        System.assert(result.fixSteps.size() > 0);
        System.assert(!result.rootCause.contains('user@test.com'));
        System.assert(!result.rootCause.contains('https://api.example.com/v1'));
        System.assert(!result.rootCause.contains('abc123'));
    }

    @IsTest
    static void shouldReturnFriendlyMessageForInvalidLogId() {
        try {
            LogAnalyzerController.analyzeLog(null);
            System.assert(false, 'Era esperado erro para logId invalido.');
        } catch (AuraHandledException ex) {
            System.assert(ex.getMessage().contains('logId valido'));
        }
    }

    @IsTest
    static void shouldReturnRecentLogsFromController() {
        ToolingLogService.setProvider(new FakeLogProvider());

        List<LogAnalyzerDTO.LogItem> logs = LogAnalyzerController.getRecentLogs(3);

        System.assertEquals(1, logs.size());
        System.assertEquals('ExecuteAnonymous', logs[0].operation);

        ToolingLogService.setProvider(null);
    }
}
