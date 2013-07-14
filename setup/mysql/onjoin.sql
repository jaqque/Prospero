--
-- Table structure for table `onjoin`
--

CREATE TABLE `onjoin` (
  `nick` varchar(20) NOT NULL default '',
  `channel` varchar(30) NOT NULL default '',
  `message` varchar(255) NOT NULL default '',
  `modified_by` varchar(20) NOT NULL default 'nobody',
  `modified_time` int(11) NOT NULL default '0',
  PRIMARY KEY  (`nick`,`channel`)
) TYPE=MyISAM;
