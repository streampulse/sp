USE `sp`;
DROP procedure IF EXISTS `update_site_table`;

DELIMITER $$
USE `sp`$$
CREATE PROCEDURE `update_site_table` ()
BEGIN
	-- SET SQL_SAFE_UPDATES = 0; 
	set @varlist := (select group_concat(distinct variable) from data where region='AZ' and site='LV');
	update site set variableList=@varlist where region='AZ' and site='LV';
	set @firstrec := (select min(DateTime_UTC) from data where region='AZ' and site='LV');
	update site set firstRecord=@firstrec where region='AZ' and site='LV';
	set @lastrec := (select max(DateTime_UTC) from data where region='AZ' and site='LV');
	update site set lastRecord=@lastrec where region='AZ' and site='LV';
END
$$

DELIMITER ;