/*
 Navicat MySQL Data Transfer

 Source Server         : localhost
 Source Server Version : 50625
 Source Host           : localhost
 Source Database       : ngxstat

 Target Server Version : 50625
 File Encoding         : utf-8

 Date: 01/18/2016 15:48:20 PM
*/

SET NAMES utf8;
SET FOREIGN_KEY_CHECKS = 0;

-- ----------------------------
--  Table structure for `connection_count`
-- ----------------------------
DROP TABLE IF EXISTS `connection_count`;
CREATE TABLE `connection_count` (
  `log_time` datetime NOT NULL,
  `connection_count` int(11) NOT NULL,
  `server_ip` varchar(255) NOT NULL,
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `application_type` varchar(255) NOT NULL DEFAULT 'default',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- ----------------------------
--  Table structure for `errorcode`
-- ----------------------------
DROP TABLE IF EXISTS `errorcode`;
CREATE TABLE `errorcode` (
  `log_time` datetime NOT NULL,
  `happen_count` int(11) NOT NULL,
  `status_code` int(11) NOT NULL,
  `server_ip` varchar(255) NOT NULL,
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `application_type` varchar(255) NOT NULL DEFAULT 'default',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- ----------------------------
--  Table structure for `req_count`
-- ----------------------------
DROP TABLE IF EXISTS `req_count`;
CREATE TABLE `req_count` (
  `log_time` datetime NOT NULL,
  `request_count` int(11) NOT NULL,
  `request_type` varchar(255) NOT NULL,
  `server_ip` varchar(255) NOT NULL,
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `application_type` varchar(255) NOT NULL DEFAULT 'default',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- ----------------------------
--  Table structure for `requesttime`
-- ----------------------------
DROP TABLE IF EXISTS `requesttime`;
CREATE TABLE `requesttime` (
  `log_time` datetime NOT NULL,
  `request_time` double(11,4) DEFAULT NULL,
  `request_url` varchar(255) NOT NULL,
  `server_ip` varchar(255) NOT NULL,
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `application_type` varchar(255) NOT NULL DEFAULT 'default',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- ----------------------------
--  Table structure for `spider_count`
-- ----------------------------
DROP TABLE IF EXISTS `spider_count`;
CREATE TABLE `spider_count` (
  `log_time` datetime NOT NULL,
  `filter_count` int(11) NOT NULL,
  `filter_type` varchar(255) NOT NULL,
  `server_ip` varchar(255) NOT NULL,
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `application_type` varchar(255) NOT NULL DEFAULT 'default',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

SET FOREIGN_KEY_CHECKS = 1;
