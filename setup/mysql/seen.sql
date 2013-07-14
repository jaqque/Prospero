--
-- Table structure for table `seen`
--

CREATE TABLE `seen` (
  `nick` varchar(20) NOT NULL default '',
  `time` int(11) NOT NULL default '0',
  `channel` varchar(30) NOT NULL default '',
  `host` varchar(64) NOT NULL default '',
  `message` tinytext NOT NULL,
  PRIMARY KEY  (`nick`)
) TYPE=MyISAM;
