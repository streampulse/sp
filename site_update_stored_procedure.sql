USE `sp`;
DROP procedure IF EXISTS `update_site_table`;

-- DELIMITER $$
CREATE PROCEDURE `update_site_table` ()
BEGIN
	-- SET SQL_SAFE_UPDATES = 0; 
	set @varlist := (select group_concat(distinct variable) from data where region='RR' and site='SS');
	update site set variableList=@varlist where region='RR' and site='SS';
	set @firstrec := (select min(DateTime_UTC) from data where region='RR' and site='SS');
	update site set firstRecord=@firstrec where region='RR' and site='SS';
	set @lastrec := (select max(DateTime_UTC) from data where region='RR' and site='SS');
	update site set lastRecord=@lastrec where region='RR' and site='SS';
END
-- $$

-- DELIMITER ;
