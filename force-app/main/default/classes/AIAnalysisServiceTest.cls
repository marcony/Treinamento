@IsTest
private class AIAnalysisServiceTest {
    @IsTest
    static void shouldAnalyzeNullPointerSignal() {
        String summaryJson = '{'
            + '"exceptionType":"System.NullPointerException",'
            + '"message":"Attempt to de-reference a null object",'
            + '"evidence":["line A","line B"],'
            + '"limits":{"soql":3,"dml":1,"cpuMs":200},'
            + '"signals":["Null reference before DML"]'
            + '}';

        LogAnalyzerDTO.Result result = AIAnalysisService.analyze(summaryJson);

        System.assert(result.rootCause.contains('System.NullPointerException'));
        System.assertEquals(2, result.evidence.size());
        System.assert(result.fixSteps.size() > 0);
        System.assert(result.prevention.size() > 0);
        System.assert(result.code.contains('record'));
    }

    @IsTest
    static void shouldAnalyzeNPlusOneSignal() {
        String summaryJson = '{'
            + '"exceptionType":"",'
            + '"message":"",'
            + '"evidence":[], '
            + '"limits":{"soql":35,"dml":2,"cpuMs":3000},'
            + '"signals":["Possible N+1 query pattern"]'
            + '}';

        LogAnalyzerDTO.Result result = AIAnalysisService.analyze(summaryJson);

        System.assertEquals('Unknown failure', result.rootCause);
        System.assert(result.fixSteps[0].contains('SOQL'));
    }

    @IsTest
    static void shouldFallbackWhenJsonIsBlank() {
        LogAnalyzerDTO.Result result = AIAnalysisService.analyze(null);

        System.assertEquals('Unknown failure', result.rootCause);
        System.assert(result.fixSteps.size() > 0);
    }

    @IsTest
    static void shouldMaskSensitiveData() {
        String input = 'Email user@test.com token Bearer abc123 access_token=xyz789 url https://api.example.com/v1/logs';

        String masked = AIAnalysisService.maskSensitiveData(input);

        System.assert(!masked.contains('user@test.com'));
        System.assert(!masked.contains('abc123'));
        System.assert(!masked.contains('xyz789'));
        System.assert(!masked.contains('https://api.example.com/v1/logs'));
        System.assert(masked.contains('[MASKED_EMAIL]'));
        System.assert(masked.contains('[MASKED_TOKEN]'));
        System.assert(masked.contains('[MASKED_URL]'));
    }
}
