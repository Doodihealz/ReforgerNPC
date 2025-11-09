-- --------------------------------------------------------
-- Host:                         127.0.0.1
-- Server version:               8.4.4 - MySQL Community Server - GPL
-- Server OS:                    Win64
-- HeidiSQL Version:             12.11.0.7082
-- --------------------------------------------------------

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET NAMES utf8 */;
/*!50503 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;


-- Dumping database structure for acore_world
CREATE DATABASE IF NOT EXISTS `acore_world` /*!40100 DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci */ /*!80016 DEFAULT ENCRYPTION='N' */;
USE `acore_world`;

-- Dumping structure for table acore_world.item_enchantment_random_tiers
CREATE TABLE IF NOT EXISTS `item_enchantment_random_tiers` (
  `enchantID` int DEFAULT NULL,
  `tier` int DEFAULT NULL,
  `class` varchar(11) NOT NULL,
  `comment` varchar(255) DEFAULT NULL,
  UNIQUE KEY `enchantID` (`enchantID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;

-- Dumping data for table acore_world.item_enchantment_random_tiers: ~127 rows (approximately)
DELETE FROM `item_enchantment_random_tiers`;
INSERT INTO `item_enchantment_random_tiers` (`enchantID`, `tier`, `class`, `comment`) VALUES
	(1, 2, 'WEAPON', 'Rockbiter 3'),
	(3, 2, 'WEAPON', 'Flametongue 3'),
	(524, 3, 'WEAPON', 'Frostbrand 3'),
	(525, 3, 'WEAPON', 'Windfury 3'),
	(343, 2, 'ANY', '+8 Agility'),
	(195, 1, 'ANY', '+14 Critical Strike Rating'),
	(196, 2, 'ANY', '+28 Critical Strike Rating'),
	(197, 3, 'ANY', '+42 Critical Strike Rating'),
	(198, 4, 'ANY', '+56 Critical Strike Rating'),
	(211, 1, 'ANY', '+7 Spell Power'),
	(212, 1, 'ANY', '+8 Spell Power'),
	(347, 1, 'ARMOR', '+44 Armor'),
	(348, 1, 'ARMOR', '+48 Armor'),
	(349, 2, 'ANY', '+9 Agility'),
	(350, 2, 'ANY', '+8 Intellect'),
	(351, 2, 'ANY', '+8 Spirit'),
	(353, 2, 'ANY', '+8 Stamina'),
	(354, 2, 'ANY', '+9 Intellect'),
	(355, 2, 'ANY', '+9 Spirit'),
	(356, 2, 'ANY', '+9 Stamina'),
	(357, 2, 'ANY', '+9 Strength'),
	(384, 2, 'ANY', '+56 Armor'),
	(385, 2, 'ANY', '+60 Armor'),
	(803, 1, 'WEAPON', 'Fiery Weapon'),
	(910, 1, 'ANY', 'Increased Stealth'),
	(911, 1, 'Armor', 'Minor Speed Increase'),
	(1003, 1, 'ANY', 'Venomhide Poison'),
	(1046, 3, 'ANY', '+19 Strength'),
	(1053, 4, 'ANY', '+26 Strength'),
	(1054, 4, 'ANY', '+27 Strength'),
	(1072, 3, 'ANY', '+19 Stamina'),
	(1073, 3, 'ANY', '+20 Stamina'),
	(1096, 3, 'ANY', '+19 Agility'),
	(1097, 3, 'ANY', '+20 Agility'),
	(1105, 4, 'ANY', '+28 Agility'),
	(1106, 4, 'ANY', '+29 Agility'),
	(1122, 3, 'ANY', '+19 Intellect'),
	(1123, 3, 'ANY', '+20 Intellect'),
	(1131, 4, 'ANY', '+28 Intellect'),
	(1132, 4, 'ANY', '+29 Intellect'),
	(1148, 3, 'ANY', '+19 Spirit'),
	(1149, 3, 'ANY', '+20 Spirit'),
	(1156, 4, 'ANY', '+27 Spirit'),
	(1157, 4, 'ANY', '+28 Spirit'),
	(1262, 3, 'ARMOR', '+20 Arcane Resistance'),
	(1266, 4, 'ARMOR', '+24 Arcane Resistance'),
	(1267, 4, 'ARMOR', '+25 Arcane Resistance'),
	(1308, 3, 'ARMOR', '+20 Frost Resistance'),
	(1312, 4, 'ARMOR', '+24 Frost Resistance'),
	(1313, 4, 'ARMOR', '+25 Frost Resistance'),
	(1354, 3, 'ARMOR', '+20 Fire Resistance'),
	(1359, 4, 'ARMOR', '+25 Fire Resistance'),
	(1360, 4, 'ARMOR', '+26 Fire Resistance'),
	(1400, 3, 'ARMOR', '+20 Nature Resistance'),
	(1404, 4, 'ARMOR', '+24 Nature Resistance'),
	(1405, 4, 'ARMOR', '+25 Nature Resistance'),
	(1446, 3, 'ARMOR', '+20 Shadow Resistance'),
	(1450, 4, 'ARMOR', '+24 Shadow Resistance'),
	(1451, 4, 'ARMOR', '+25 Shadow Resistance'),
	(1504, 3, 'ANY', '+125 Armor'),
	(1587, 3, 'ANY', '+16 Attack Power'),
	(1588, 3, 'ANY', '+18 Attack Power'),
	(1598, 4, 'ANY', '+38 Attack Power'),
	(1599, 4, 'ANY', '+40 Attack Power'),
	(1894, 1, 'WEAPON', 'Icy Weapon'),
	(1898, 1, 'WEAPON', 'Lifestealing'),
	(1899, 1, 'WEAPON', 'Unholy Weapon'),
	(1900, 1, 'WEAPON', 'Crusader'),
	(2050, 1, 'ANY', '+26 Ranged Attack Power'),
	(2051, 1, 'ANY', '+29 Ranged Attack Power'),
	(2055, 2, 'ANY', '+38 Ranged Attack Power'),
	(2056, 2, 'ANY', '+41 Ranged Attack Power'),
	(2060, 3, 'ANY', '+50 Ranged Attack Power'),
	(2061, 3, 'ANY', '+53 Ranged Attack Power'),
	(2066, 4, 'ANY', '+65 Ranged Attack Power'),
	(2067, 4, 'ANY', '+67 Ranged Attack Power'),
	(2073, 5, 'ANY', '+82 Ranged Attack Power'),
	(2074, 5, 'ANY', '+84 Ranged Attack Power'),
	(2015, 4, 'ARMOR', '+42 Defense Rating'),
	(2396, 1, 'ANY', '+14 Mana every 5 sec'),
	(2399, 1, 'ANY', '+15 Mana every 5 sec'),
	(2434, 1, 'ANY', '+9 Health every 5 sec'),
	(2438, 1, 'ANY', '+10 Health every 5 sec'),
	(2585, 3, 'ARMOR', '+28 Attack Power / +12 Dodge Rating'),
	(2586, 3, 'ARMOR', '+24 Ranged Attack Power / +10 Stamina / +10 Hit Rating'),
	(2587, 3, 'ARMOR', '+13 Spell Power / +15 Intellect'),
	(2588, 3, 'ARMOR', '+18 Spell Power / +8 Hit Rating'),
	(2589, 3, 'ARMOR', '+18 Spell Power / +10 Stamina'),
	(2590, 3, 'ARMOR', '+13 Spell Power / +10 Stamina / +5 Mana every 5 sec'),
	(2673, 3, 'WEAPON', 'Mongoose'),
	(2678, 3, 'WEAPON', 'Brilliant Wizard Oil (Superior)'),
	(2675, 3, 'WEAPON', 'Battlemaster'),
	(25, 2, 'WEAPON', 'Shadow Oil'),
	(26, 2, 'WEAPON', 'Frost Oil'),
	(2319, 2, 'ANY', '+15 Spell Power'),
	(2320, 2, 'ANY', '+16 Spell Power'),
	(2327, 3, 'ANY', '+25 Spell Power'),
	(2328, 3, 'ANY', '+26 Spell Power'),
	(2339, 4, 'ANY', '+39 Spell Power'),
	(2340, 4, 'ANY', '+40 Spell Power'),
	(3836, 5, 'ANY', '+70 Spell Power and +6 Mana / 5 sec'),
	(3854, 5, 'ANY', '+81 Spell Power'),
	(69, 1, 'ANY', '+2 Strength'),
	(70, 1, 'ANY', '+3 Strength'),
	(72, 1, 'ANY', '+2 Stamina'),
	(73, 1, 'ANY', '+3 Stamina'),
	(75, 1, 'ANY', '+2 Agility'),
	(76, 1, 'ANY', '+3 Agility'),
	(80, 1, 'ANY', '+2 Intellect'),
	(81, 1, 'ANY', '+3 Intellect'),
	(83, 1, 'ANY', '+2 Spirit'),
	(84, 1, 'ANY', '+3 Spirit'),
	(1047, 3, 'ANY', '+20 Strength'),
	(1231, 5, 'ANY', '+45 Spirit'),
	(1232, 5, 'ANY', '+46 Spirit'),
	(3827, 5, 'ANY', '+110 Attack Power'),
	(3874, 5, 'ANY', '+130 Attack Power'),
	(3856, 5, 'ANY', '+100 Agility'),
	(3851, 5, 'ANY', '+50 Stamina'),
	(3860, 5, 'ANY', '+885 Armor'),
	(3737, 5, 'ANY', '+34 Intellect'),
	(3732, 5, 'ANY', '+34 Strength'),
	(3735, 5, 'ANY', '+34 Spirit'),
	(3739, 5, 'ANY', '+34 Haste'),
	(3738, 5, 'ANY', '+34 Critical Strike Rating'),
	(3733, 5, 'ANY', '+34 Agility'),
	(3850, 5, 'ANY', '+40 Stamina');

/*!40103 SET TIME_ZONE=IFNULL(@OLD_TIME_ZONE, 'system') */;
/*!40101 SET SQL_MODE=IFNULL(@OLD_SQL_MODE, '') */;
/*!40014 SET FOREIGN_KEY_CHECKS=IFNULL(@OLD_FOREIGN_KEY_CHECKS, 1) */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40111 SET SQL_NOTES=IFNULL(@OLD_SQL_NOTES, 1) */;
