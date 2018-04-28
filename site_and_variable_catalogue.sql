-- all sites
select region, site, name, latitude, longitude, usgs from site
	into outfile '/var/lib/mysql-files/allSites_20180416.csv'
	fields terminated by ',' enclosed by '"' lines terminated by '\n';

-- variables by site (requries manual editing of csv)
select distinct region, site, dbcol from cols order by region, site
	into outfile '/var/lib/mysql-files/varsBySite_20180416.csv'
	fields terminated by ',' enclosed by '"' lines terminated by '\n';
