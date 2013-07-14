--
-- Table structure for table `stats`
--

CREATE TABLE `stats` (
  `nick` varchar(20) NOT NULL default '',
  `type` varchar(8) NOT NULL default '',
  `channel` varchar(30) NOT NULL default 'PRIVATE',
  `time` int(10) unsigned default '0',
  `counter` smallint(5) unsigned default '0',
  PRIMARY KEY  (`nick`,`type`,`channel`)
) TYPE=MyISAM;
