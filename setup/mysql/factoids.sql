--
-- Table structure for table `factoids`
--

CREATE TABLE `factoids` (
  `factoid_key` varchar(64) NOT NULL,
  `requested_by` varchar(100) default NULL,
  `requested_time` int(11) default NULL,
  `requested_count` smallint(5) unsigned NOT NULL default '0',
  `created_by` varchar(100) default NULL,
  `created_time` int(11) default NULL,
  `modified_by` varchar(100) default NULL,
  `modified_time` int(11) default NULL,
  `locked_by` varchar(100) default NULL,
  `locked_time` int(11) default NULL,
  `factoid_value` text NOT NULL,
  PRIMARY KEY  (`factoid_key`)
) TYPE=MyISAM;
