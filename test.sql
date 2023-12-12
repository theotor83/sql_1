DROP TABLE IF EXISTS JOUEUR;
CREATE TABLE JOUEUR(
NomJoueur VARCHAR(10) PRIMARY KEY,
ArgentJoueur INTEGER DEFAULT 100) ;

DROP TABLE IF EXISTS OBJET;
CREATE TABLE OBJET(
NomObjet VARCHAR(10) PRIMARY KEY,
TypeObjet VARCHAR(10),
Effet real,
CoutObjet INTEGER) ;

DROP TABLE IF EXISTS ENTITE;
CREATE TABLE ENTITE(
Nom VARCHAR(10) PRIMARY KEY,
PVmax INTEGER,
PVmaxbase INTEGER,
PVactuels INTEGER,
Attaque INTEGER,
Attaquebase INTEGER,
Defense INTEGER,
Defensebase INTEGER,
LettreType CHAR(1) CHECK (LettreType IN ('M', 'A')));

/*L'horreur en haut avec les colonnes "base", c'est pour calculer les boosts de stats grâce aux objets. Sans ça, les pourcentages marchent mal et sont inconsistants.*/

DROP TABLE IF EXISTS SKILL;
CREATE TABLE SKILL (
NomSkill VARCHAR(10) PRIMARY KEY,
TypeSkill VARCHAR(10),
EffetSkill real);

DROP TABLE IF EXISTS ObjetAchete;
CREATE TABLE ObjetAchete(
NomJoueur VARCHAR(10) REFERENCES JOUEUR,
NomObjet VARCHAR(10) REFERENCES OBJET,
qte INTEGER NOT NULL,
PRIMARY KEY(NomJoueur, NomObjet),
FOREIGN KEY (NomJoueur) REFERENCES JOUEUR(NomJoueur),
FOREIGN KEY (NomObjet) REFERENCES OBJET(NomObjet));

DROP TABLE IF EXISTS MagazinPerso;
CREATE TABLE MagazinPerso(
Nom VARCHAR(10) REFERENCES ENTITE,
NomJoueur VARCHAR(10) REFERENCES Joueur,
CoutAllie INTEGER,
PRIMARY KEY(Nom, NomJoueur),
FOREIGN KEY (Nom) REFERENCES ENTITE(Nom),
FOREIGN KEY (NomJoueur) REFERENCES JOUEUR(NomJoueur));

DROP TABLE IF EXISTS PersoPossede;
CREATE TABLE PersoPossede(
NomJoueur VARCHAR(10) REFERENCES Joueur,
Nom VARCHAR(10) REFERENCES ENTITE,
PRIMARY KEY(NomJoueur,Nom),
FOREIGN KEY (NomJoueur) REFERENCES JOUEUR(NomJoueur),
FOREIGN KEY (Nom) REFERENCES ENTITE(Nom));

DROP TABLE IF EXISTS SkillEntite;
CREATE TABLE SkillEntite(
Nom VARCHAR(10) REFERENCES ENTITE,
NomSkill VARCHAR(10) REFERENCES SKILL,
PRIMARY KEY (Nom, NomSkill),
FOREIGN KEY (Nom) REFERENCES ENTITE(Nom),
FOREIGN KEY (NomSkill) REFERENCES SKILL(NomSkill));

DROP TABLE IF EXISTS Monstre;
CREATE TABLE Monstre(
Nom VARCHAR(10) REFERENCES ENTITE PRIMARY KEY,
ArgentDrop INTEGER,
IdMontre INTEGER,
FOREIGN KEY (Nom) REFERENCES ENTITE(Nom));

DROP TABLE IF EXISTS ChoixSkill;
CREATE TABLE ChoixSkill(
NomJoueur VARCHAR(10) PRIMARY KEY REFERENCES JOUEUR,
SkillChoisi VARCHAR(10));

DROP TABLE IF EXISTS COMBAT;
CREATE TABLE COMBAT(
Nom VARCHAR(10) PRIMARY KEY REFERENCES ENTITE,
PVactuels INTEGER,
Attaque INTEGER,
Defense INTEGER,
LettreType CHAR(1) CHECK (LettreType IN ('M', 'A')));

/* ========================= DEBUT TRIGGERS ========================= */

DROP TRIGGER if EXISTS AchatObjet;
CREATE TRIGGER AchatObjet
BEFORE UPDATE ON ObjetAchete
WHEN (SELECT ArgentJoueur FROM JOUEUR WHERE NomJoueur = NEW.NomJoueur) >= ((SELECT CoutObjet FROM OBJET WHERE NomObjet = NEW.NomObjet) * (NEW.qte - OLD.qte))
BEGIN
   UPDATE ObjetAchete
   SET qte = qte + NEW.qte
   WHERE NomObjet = NEW.NomObjet;
   UPDATE JOUEUR
   SET ArgentJoueur = (SELECT ArgentJoueur FROM JOUEUR WHERE NomJoueur = NEW.NomJoueur) - ((SELECT CoutObjet FROM OBJET WHERE NomObjet = NEW.NomObjet) * (NEW.qte - OLD.qte));
END;

DROP TRIGGER IF EXISTS AchatObjetRefuse;
CREATE TRIGGER AchatObjetRefuse
BEFORE UPDATE ON ObjetAchete
WHEN (SELECT ArgentJoueur FROM JOUEUR WHERE NomJoueur = NEW.NomJoueur) < ((SELECT CoutObjet FROM OBJET WHERE NomObjet = NEW.NomObjet) * (NEW.qte - OLD.qte))
OR (SELECT ArgentJoueur FROM JOUEUR WHERE NomJoueur = NEW.NomJoueur) IS NULL
BEGIN
	SELECT CASE
		WHEN NEW.qte <> OLD.qte THEN
			RAISE (ABORT,"Vous n'avez pas assez d'argent.")
	END;
END;

DROP TRIGGER IF EXISTS AchatObjetRefuseCombat;
CREATE TRIGGER AchatObjetRefuseCombat
BEFORE UPDATE ON ObjetAchete
WHEN (SELECT COUNT(*) FROM COMBAT) > 0
BEGIN
	SELECT RAISE (ABORT,"Vous ne pouvez pas acheter en combat.");
END;



DROP TRIGGER IF EXISTS AchatPerso;
CREATE TRIGGER AchatPerso
BEFORE INSERT ON PersoPossede
WHEN (SELECT ArgentJoueur FROM JOUEUR WHERE NomJoueur = NEW.NomJoueur) >= 
    (SELECT CoutAllie FROM MagazinPerso WHERE NomJoueur = NEW.NomJoueur AND Nom = NEW.Nom)
BEGIN
  UPDATE JOUEUR
  SET ArgentJoueur = (SELECT ArgentJoueur FROM JOUEUR WHERE NomJoueur = NEW.NomJoueur) - 
                    (SELECT CoutAllie FROM MagazinPerso WHERE NomJoueur = NEW.NomJoueur AND Nom = NEW.Nom);
END;

DROP TRIGGER IF EXISTS AchatPersoRefuse;
CREATE TRIGGER AchatPersoRefuse
BEFORE INSERT ON PersoPossede
WHEN (SELECT ArgentJoueur FROM JOUEUR WHERE NomJoueur = NEW.NomJoueur) < (SELECT CoutAllie FROM MagazinPerso WHERE NomJoueur = NEW.NomJoueur AND Nom = NEW.Nom)
OR (SELECT ArgentJoueur FROM JOUEUR WHERE NomJoueur = NEW.NomJoueur) IS NULL
BEGIN
	SELECT RAISE(ABORT,"Vous n'avez pas assez d'argent.");
END;

DROP TRIGGER IF EXISTS AchatPersoRefuseCombat;
CREATE TRIGGER AchatPersoRefuseCombat
BEFORE INSERT ON PersoPossede
WHEN (SELECT COUNT(*) FROM COMBAT) > 0
BEGIN
	SELECT RAISE (ABORT,"Vous ne pouvez pas acheter en combat.");
END;

DROP TRIGGER IF EXISTS DebutCombatV2;
CREATE TRIGGER DebutCombatV2
AFTER INSERT ON COMBAT
WHEN (SELECT COUNT(*) FROM ENTITE WHERE LettreType = 'M') > 0
BEGIN
	INSERT INTO COMBAT
	SELECT Nom, PVMax, Attaque, Defense, LettreType
	FROM ENTITE
	WHERE Nom IN(
		SELECT Nom
		FROM PersoPossede);
	DELETE FROM ChoixSkill;
END;
	
DROP TRIGGER IF EXISTS BoostPV;
CREATE TRIGGER BoostPV
BEFORE UPDATE ON ObjetAchete
WHEN NEW.NomObjet = 'Talisman' AND NEW.qte != OLD.qte
BEGIN
 UPDATE ENTITE
 SET PVMax = PVmaxbase + ((SELECT Effet FROM OBJET WHERE NomObjet = 'Talisman') * PVMaxBase) * NEW.qte
 WHERE LettreType = 'A';
END;

/*A changer : faire en sorte que la vérification soit TypeObjet = Augmente_Vie, mais j'ai la flemme de faire ça. Actuellement ça marche donc c'est pas grave.*/

DROP TRIGGER IF EXISTS BoostDEF;
CREATE TRIGGER BoostDEF
AFTER UPDATE ON ObjetAchete
WHEN NEW.NomObjet = 'Amulette' AND NEW.qte != OLD.qte
BEGIN
 UPDATE ENTITE
 SET Defense = DefenseBase + ((SELECT Effet FROM OBJET WHERE NomObjet = 'Amulette') * DefenseBase) * NEW.qte
 WHERE LettreType = 'A';
END;

/*A changer : faire en sorte que la vérification soit TypeObjet = Augmente_Def, mais j'ai la flemme de faire ça. Actuellement ça marche donc c'est pas grave.*/

DROP TRIGGER IF EXISTS BoostATK;
CREATE TRIGGER BoostATK
AFTER UPDATE ON ObjetAchete
WHEN NEW.NomObjet = 'Baton' AND NEW.qte != OLD.qte
BEGIN
 UPDATE ENTITE
 SET Attaque = AttaqueBase + ((SELECT Effet FROM OBJET WHERE NomObjet = 'Baton') * AttaqueBase) * NEW.qte
 WHERE LettreType = 'A';
END;

/*A changer : faire en sorte que la vérification soit TypeObjet = Augmente_Atk, mais j'ai la flemme de faire ça. Actuellement ça marche donc c'est pas grave.*/

DROP TRIGGER IF EXISTS CheckSkillInsert;
CREATE TRIGGER CheckSkillInsert
BEFORE INSERT ON ChoixSkill
BEGIN
    SELECT CASE
        WHEN NEW.SkillChoisi NOT IN (
            SELECT SkillEntite.NomSkill
            FROM SkillEntite, PersoPossede
            WHERE PersoPossede.Nom = SkillEntite.Nom
        ) THEN
            RAISE(ABORT, "Ce skill n'est pas disponible.")
    END;
END;

DROP TRIGGER IF EXISTS CheckSkillUpdate;
CREATE TRIGGER CheckSkillUpdate
BEFORE UPDATE ON ChoixSkill
BEGIN
    SELECT CASE
        WHEN NEW.SkillChoisi NOT IN (
            SELECT SkillEntite.NomSkill
            FROM SkillEntite, PersoPossede
            WHERE PersoPossede.Nom = SkillEntite.Nom
        ) THEN
            RAISE(ABORT, "Ce skill n'est pas disponible.")
    END;
END;


DROP TRIGGER IF EXISTS VictoireV2;
CREATE TRIGGER VictoireV2
AFTER UPDATE ON COMBAT
BEGIN
   UPDATE JOUEUR
   SET ArgentJoueur = ArgentJoueur + (SELECT ArgentDrop FROM Monstre WHERE Nom = NEW.Nom)
   WHERE (SELECT COUNT(*) FROM COMBAT WHERE LettreType = 'M' AND PVactuels = 0) = (SELECT COUNT(*) FROM COMBAT WHERE LettreType = 'M');
END;

DROP TRIGGER IF EXISTS DefaiteV2;
CREATE TRIGGER DefaiteV2
AFTER UPDATE ON COMBAT
BEGIN
   UPDATE JOUEUR
   SET ArgentJoueur = 666
   WHERE (SELECT COUNT(*) FROM COMBAT WHERE LettreType = 'A' AND PVactuels = 0) = (SELECT COUNT(*) FROM COMBAT WHERE LettreType = 'A');
END;

DROP TRIGGER IF EXISTS FinDeCombat;
CREATE TRIGGER FinDeCombat
AFTER UPDATE ON JOUEUR
BEGIN
   DELETE FROM COMBAT;
   DELETE FROM ChoixSkill;
END;
 
DROP TRIGGER IF EXISTS FinDuJeu;
CREATE TRIGGER FinDuJeu
AFTER UPDATE ON JOUEUR
WHEN (SELECT ArgentJoueur FROM JOUEUR) IS NULL
BEGIN
	DELETE FROM PersoPossede;
END;

/*DROP TRIGGER IF EXISTS ActiverSkillUpdate;
CREATE TRIGGER ActiverSkill
AFTER UPDATE ON ChoixSkill
WHEN (SELECT COUNT(*) FROM COMBAT) > 0
BEGIN
	UPDATE FROM COMBAT
	*/

DROP TRIGGER IF EXISTS ActiverSkillOffensifUpdate;
CREATE TRIGGER ActiverSkillOffensifUpdate
AFTER UPDATE ON ChoixSkill
WHEN (SELECT COUNT(*) FROM COMBAT) > 0 AND NEW.SkillChoisi IN (SELECT NomSkill FROM SKILL WHERE TypeSkill = "Offensif")
BEGIN
	UPDATE COMBAT
	SET PVactuels = PVactuels - (((SELECT EffetSkill FROM SKILL WHERE NomSkill = NEW.SkillChoisi) * (SELECT SUM(Attaque) FROM COMBAT WHERE Nom IN (SELECT Nom FROM PersoPossede)))*(SELECT ((RANDOM() / 9223372036854775808.0) + 1.5) /2)) + (SELECT Defense FROM COMBAT WHERE LettreType = 'M')
	WHERE LettreType = 'M';
END;

DROP TRIGGER IF EXISTS ActiverSkillOffensifInsert;
CREATE TRIGGER ActiverSkillOffensifInsert
AFTER INSERT ON ChoixSkill
WHEN (SELECT COUNT(*) FROM COMBAT) > 0 AND NEW.SkillChoisi IN (SELECT NomSkill FROM SKILL WHERE TypeSkill = "Offensif")
BEGIN
	UPDATE COMBAT
	SET PVactuels = PVactuels - (((SELECT EffetSkill FROM SKILL WHERE NomSkill = NEW.SkillChoisi) * (SELECT SUM(Attaque) FROM COMBAT WHERE Nom IN (SELECT Nom FROM PersoPossede)))*(SELECT ((RANDOM() / 9223372036854775808.0) + 1.5) /2)) + (SELECT Defense FROM COMBAT WHERE LettreType = 'M')
	WHERE LettreType = 'M';
END;
	
/* ========================= FIN TRIGGERS ========================= */

/* ========================= DEBUT VUES ========================= */

DROP VIEW IF EXISTS VueCombat;
CREATE VIEW VueCombat AS
SELECT Nom, PVactuels
FROM ENTITE
WHERE PVactuels > 0;

DROP VIEW IF EXISTS Inventaire;
CREATE VIEW Inventaire("Nom objet", "Quantité", "Type", "Boost (en %)") AS
SELECT ObjetAchete.NomObjet, ObjetAchete.qte, OBJET.TypeObjet, OBJET.Effet * ObjetAchete.qte * 100
FROM ObjetAchete, OBJET
WHERE ObjetAchete.NomObjet = OBJET.NomObjet
AND qte > 0;

DROP VIEW IF EXISTS SkillsUtilisables;
CREATE VIEW SkillsUtilisables AS
SELECT SkillEntite.Nom, SkillEntite.NomSkill
FROM SkillEntite, PersoPossede
WHERE PersoPossede.Nom = SkillEntite.Nom;

DROP VIEW IF EXISTS StatsEquipe;
CREATE VIEW StatsEquipe AS
SELECT ENTITE.Nom, ENTITE.PVMax, ENTITE.Attaque, ENTITE.Defense
FROM ENTITE, PersoPossede
WHERE PersoPossede.Nom = ENTITE.Nom;

/* ========================= FIN VUES ========================= */

INSERT INTO SKILL
VALUES('Attaque Basique','Offensif',1),
('Boule Magique', 'Offensif', 1.2),
('Morsure', 'Offensif', 1.1),
('Soin', 'Soin', 20),
('Grand Soin', 'Soin', 50),
('Tres Grand Soin', 'Soin', 100);

INSERT INTO OBJET VALUES
('Talisman', 'Augmente_Vie', 0.1, 200), 
('Amulette', 'Augmente_Def', 0.2, 250), 
('Baton', 'Augmente_Atk', 0.2, 350);

INSERT INTO ENTITE VALUES
    ("Bertrand", 200, 200, 0, 35, 35, 20, 20, 'A'),
    ("Roseline", 150, 150, 0, 45, 45, 15, 15, 'A'),
    ("Igor", 350, 350, 0, 20, 20, 45, 45, 'A'),
    ("Giselle", 400, 400, 0, 50, 50, 50, 50, 'A'),
    
    ("Loup", 100, 100, 0, 30, 30, 5, 5, 'M'),
    ("Ogre", 200, 200, 0, 40, 40, 15, 15, 'M'),
    ("Gobelin", 70, 70, 0, 55, 55, 3, 3, 'M'),
    ("Blob", 50, 50, 0, 10, 10, 0, 0, 'M'),
    ("Ours", 150, 150, 0, 50, 50, 20, 20, 'M'),
    ("Sirene", 100, 100, 0, 50, 50, 10, 10, 'M'),
    ("Dragon", 400, 400, 0, 250, 250, 90, 90, 'M'),
    ("Cyclope", 250, 250, 0, 100, 100, 70, 70, 'M');

INSERT INTO JOUEUR VALUES
    ("Player", 10000000000);

INSERT INTO Monstre
VALUES('Blob',5,1),
('Gobelin',15,2),
('Loup',25,3),
('Sirene',35,4),
('Ours',50,5),
('Ogre',60,6),
('Cyclope',120,7),
('Dragon',250,8);

INSERT INTO SkillEntite
VALUES("Bertrand","Attaque Basique"),
("Roseline","Attaque Basique"),
("Igor","Attaque Basique"),
("Giselle","Attaque Basique"),
("Loup","Attaque Basique"),
("Ogre","Attaque Basique"),
("Gobelin","Attaque Basique"),
("Blob","Attaque Basique"),
("Ours","Attaque Basique"),
("Sirene","Attaque Basique"),
("Dragon","Attaque Basique"),
("Cyclope","Attaque Basique"),
("Bertrand","Soin"),
("Roseline","Soin"),
("Igor","Soin"),
("Giselle","Soin"),
("Bertrand","Grand Soin"),
("Roseline","Grand Soin"),
("Igor","Grand Soin"),
("Giselle","Grand Soin"),
("Igor","Tres Grand Soin"),
("Giselle","Tres Grand Soin"),
("Roseline","Boule Magique"),
("Giselle","Boule Magique"),
("Loup","Morsure"),
("Gobelin","Morsure"),
("Ours","Morsure"),
("Dragon","Morsure");

INSERT INTO ObjetAchete
VALUES("Player","Talisman",0),
("Player","Amulette",0),
("Player","Baton",0);

INSERT INTO MagazinPerso VALUES
	("Bertrand","Player",0),
	("Roseline","Player",1250),
	("Igor","Player",1500),
	("Giselle","Player",3000);
	
INSERT INTO PersoPossede VALUES
	("Player","Bertrand");
	
/* ===================== COMMANDES A RENTRER POUR JOUER : =====================

=== Début de combat v2 ===

INSERT INTO COMBAT
SELECT Nom, PVMax, Attaque, Defense, LettreType
FROM ENTITE
WHERE LettreType = 'M'
ORDER BY RANDOM()
LIMIT 1;

SELECT ((RANDOM() / 9223372036854775808.0) + 1.5) /2

=== Achat de perso ===

INSERT INTO PersoPossede VALUES
	("Player","Roseline");
	
	
=== Voir stats de perso ===

SELECT * FROM ENTITE
WHERE Nom = "[Nom du perso]";


=== Voir argent du joueur ===

SELECT ArgentJoueur FROM JOUEUR
WHERE NomJoueur = "[Nom du joueur]";

=== Choisir une attaque ===

INSERT INTO ChoixSkill(NomJoueur, SkillChoisi) 
VALUES ("Player", "Attaque Basique")
ON CONFLICT(NomJoueur) DO UPDATE SET SkillChoisi = "Attaque Basique";
*/
