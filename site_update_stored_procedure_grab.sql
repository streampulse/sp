USE `sp`;
DROP procedure IF EXISTS `update_site_table_grab`;

-- DELIMITER $$
CREATE PROCEDURE `update_site_table_grab` ()
BEGIN
	-- SET SQL_SAFE_UPDATES = 0; 
	set @varlist := (select group_concat(distinct variable) from grabdata where region='RR' and site='SS');
	update site set grabVarList=@varlist where region='RR' and site='SS';
END
-- $$

-- DELIMITER ;
