TRUNCATE `audit_dev`.`zaudit`;
TRUNCATE `audit_dev`.`zaudit_meta`;


CALL `audit_dev`.`zsp_generate_audit`('audit_dev', 'test_data', @script, @errors);
SELECT @script, @errors;


CALL `audit_dev`.`zsp_generate_audit`('audit_dev', 'multi_key', @script, @errors);
SELECT @script, @errors;


CALL `audit_dev`.`zsp_generate_batch_audit`('audit_dev', 'test_data,multi_key', @script, @errors);
SELECT @script, @errors;


CALL `audit_dev`.`zsp_generate_remove_audit`('audit_dev', 'test_data', @script);
SELECT @script;

CALL `audit_dev`.`zsp_generate_batch_remove_audit`('audit_dev', 'test_data,multi_key', @script);
SELECT @script;




















