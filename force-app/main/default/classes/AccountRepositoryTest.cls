@IsTest
private class AccountRepositoryTest {
    @IsTest
    static void shouldNormalizeTipo() {
        System.assertEquals('PF', AccountRepository.normalizeTipo(' pf '));
        System.assertEquals('PJ', AccountRepository.normalizeTipo('pj'));
        System.assertEquals('', AccountRepository.normalizeTipo(null));
    }

    @IsTest
    static void shouldValidateCpfForPf() {
        System.assertEquals(true, AccountRepository.validarCpfCnpj('PF', '529.982.247-25'));
        System.assertEquals(true, AccountRepository.validarCpfCnpj('pf', '52998224725'));
        System.assertEquals(false, AccountRepository.validarCpfCnpj('PF', '111.111.111-11'));
    }

    @IsTest
    static void shouldValidateCnpjForPj() {
        System.assertEquals(true, AccountRepository.validarCpfCnpj('PJ', '11.444.777/0001-61'));
        System.assertEquals(true, AccountRepository.validarCpfCnpj('pj', '11444777000161'));
        System.assertEquals(false, AccountRepository.validarCpfCnpj('PJ', '11.111.111/1111-11'));
    }

    @IsTest
    static void shouldReturnFalseForUnknownTipoOrNullRecordType() {
        System.assertEquals(false, AccountRepository.validarCpfCnpj('XX', '52998224725'));
        System.assertEquals(false, AccountRepository.validarCpfCnpjByRecordTypeId(null, '52998224725'));
        System.assertEquals('', AccountRepository.getTipoByRecordTypeId(null));
    }
}
