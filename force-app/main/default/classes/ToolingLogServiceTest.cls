@IsTest
private class ToolingLogServiceTest {
    private class LogBodyMock implements HttpCalloutMock {
        Integer statusCode;
        String responseBody;

        LogBodyMock(Integer statusCode, String responseBody) {
            this.statusCode = statusCode;
            this.responseBody = responseBody;
        }

        public HttpResponse respond(HttpRequest req) {
            System.assertEquals('GET', req.getMethod());
            System.assert(req.getEndpoint().contains('/services/data/v63.0/tooling/sobjects/ApexLog/'));
            System.assert(req.getEndpoint().endsWith('/Body/'));

            HttpResponse res = new HttpResponse();
            res.setStatusCode(statusCode);
            res.setBody(responseBody);
            return res;
        }
    }

    private class FakeLogProvider implements ToolingLogService.LogProvider {
        Integer lastLimit;

        public List<ApexLog> fetch(Integer limitSize) {
            lastLimit = limitSize;
            return new List<ApexLog>{
                new ApexLog(
                    Id = '07L000000000001AAA',
                    Operation = 'AnonymousBlock',
                    Status = 'Success',
                    DurationMilliseconds = 120,
                    LogLength = 2450,
                    StartTime = System.now()
                )
            };
        }
    }

    @IsTest
    static void shouldReturnMappedRecentLogs() {
        FakeLogProvider fake = new FakeLogProvider();
        ToolingLogService.setProvider(fake);

        Test.startTest();
        List<LogAnalyzerDTO.LogItem> items = ToolingLogService.getRecentLogs(5);
        Test.stopTest();

        System.assertEquals(5, fake.lastLimit);
        System.assertEquals(1, items.size());
        System.assertEquals('AnonymousBlock', items[0].operation);
        System.assertEquals('Success', items[0].status);

        ToolingLogService.setProvider(null);
    }

    @IsTest
    static void shouldApplyDefaultLimitWhenInputIsInvalid() {
        FakeLogProvider fake = new FakeLogProvider();
        ToolingLogService.setProvider(fake);

        ToolingLogService.getRecentLogs(0);

        System.assertEquals(20, fake.lastLimit);
        ToolingLogService.setProvider(null);
    }

    @IsTest
    static void shouldThrowWhenLogIdIsNull() {
        try {
            ToolingLogService.getBody(null, 200000);
            System.assert(false, 'Era esperado erro para logId nulo.');
        } catch (AuraHandledException ex) {
            System.assert(ex.getMessage().contains('Informe um logId valido'));
        }
    }

    @IsTest
    static void shouldThrowWhenIdIsNotApexLog() {
        Account acc = new Account(Name = 'Teste');
        insert acc;

        try {
            ToolingLogService.getBody(acc.Id, 200000);
            System.assert(false, 'Era esperado erro para Id de objeto diferente de ApexLog.');
        } catch (AuraHandledException ex) {
            System.assert(ex.getMessage().contains('Formato de logId invalido'));
        }
    }

    @IsTest
    static void shouldReturnBodyTruncatedFromTheEnd() {
        Id logId = '07L000000000001AAA';
        Test.setMock(HttpCalloutMock.class, new LogBodyMock(200, '1234567890'));

        Test.startTest();
        String body = ToolingLogService.getBody(logId, 4);
        Test.stopTest();

        System.assertEquals('7890', body);
    }

    @IsTest
    static void shouldHandleUnauthorizedResponses() {
        Id logId = '07L000000000001AAA';
        Test.setMock(HttpCalloutMock.class, new LogBodyMock(401, 'unauthorized'));

        try {
            ToolingLogService.getBody(logId, 200000);
            System.assert(false, 'Era esperado erro de autorizacao.');
        } catch (AuraHandledException ex) {
            System.assert(ex.getMessage().contains('Sessao expirada'));
        }
    }

    @IsTest
    static void shouldHandleNotFoundResponses() {
        Id logId = '07L000000000001AAA';
        Test.setMock(HttpCalloutMock.class, new LogBodyMock(404, 'not found'));

        try {
            ToolingLogService.getBody(logId, 200000);
            System.assert(false, 'Era esperado erro de log inexistente.');
        } catch (AuraHandledException ex) {
            System.assert(ex.getMessage().contains('Log nao encontrado'));
        }
    }

    @IsTest
    static void shouldHandleGenericErrorResponses() {
        Id logId = '07L000000000001AAA';
        Test.setMock(HttpCalloutMock.class, new LogBodyMock(500, 'internal server error'));

        try {
            ToolingLogService.getBody(logId, 200000);
            System.assert(false, 'Era esperado erro generico.');
        } catch (AuraHandledException ex) {
            System.assert(ex.getMessage().contains('Falha ao buscar o corpo do log'));
        }
    }
}
