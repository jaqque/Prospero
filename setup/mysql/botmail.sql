--
-- Table structure for table `botmail`
--

CREATE TABLE `botmail` (
  `srcwho` varchar(20) NOT NULL default '',
  `dstwho` varchar(20) NOT NULL default '',
  `srcuh` varchar(80) NOT NULL default '',
  `time` int(10) unsigned default '0',
  `msg` text NOT NULL,
  PRIMARY KEY  (`srcwho`,`dstwho`)
) TYPE=MyISAM;
