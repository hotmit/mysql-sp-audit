

CALL `audit_dev`.`zsp_generate_audit`('audit_dev', 'test_data');
-- CALL `audit_dev`.`zsp_generate_audit`('audit_dev', 'multi_key');


CALL `audit_dev`.`zsp_generate_remove_audit`('audit_dev', 'test_data');


CALL `audit_dev`.`zsp_generate_batch_audit`('audit_dev', 'test_data,multi_key');

CALL `audit_dev`.`zsp_generate_audit`('audit_dev', 'test_data', @script, @errors);
SELECT @script, @errors;



















