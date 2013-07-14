--
-- Table structure for table `rootwarn`
--

CREATE TABLE `rootwarn` (
  `nick` varchar(20) NOT NULL default '',
  `attempt` smallint(5) unsigned default NULL,
  `time` int(11) NOT NULL default '0',
  `host` varchar(64) NOT NULL default '',
  `channel` varchar(30) NOT NULL default '',
  PRIMARY KEY  (`nick`)
) TYPE=MyISAM;
