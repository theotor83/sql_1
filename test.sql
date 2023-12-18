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
PVmaxbase INTEGER,
Attaquebase INTEGER,
Defensebase INTEGER,
LettreType CHAR(1) CHECK (LettreType IN ('M', 'A')));

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
SkillChoisi VARCHAR(10) UNIQUE REFERENCES Skill(NomSkill)
);

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
	SELECT Nom, PVMaxbase, Attaquebase, Defensebase, LettreType
	FROM ENTITE
	WHERE Nom IN(
		SELECT Nom
		FROM PersoPossede);
	DELETE FROM ChoixSkill;
END;

DROP TRIGGER IF EXISTS BoostStats;
CREATE TRIGGER BoostStats
AFTER INSERT ON COMBAT
FOR EACH ROW
WHEN NEW.LettreType = 'A'
BEGIN
	UPDATE COMBAT
	SET PVactuels = (SELECT PVMaxbase FROM ENTITE WHERE Nom = NEW.Nom) + 
				 ((SELECT Effet FROM OBJET WHERE TypeObjet = 'Augmente_Vie') * 
				 (SELECT PVMaxbase FROM ENTITE WHERE Nom = NEW.Nom) * 
				 (SELECT qte FROM ObjetAchete WHERE NomObjet IN (SELECT NomObjet FROM OBJET WHERE TypeObjet = 'Augmente_Vie')))
	WHERE LettreType = 'A' AND Nom = NEW.Nom;
	UPDATE COMBAT
	SET Defense = (SELECT Defensebase FROM ENTITE WHERE Nom = NEW.Nom) + 
				 ((SELECT Effet FROM OBJET WHERE TypeObjet = 'Augmente_Def') * 
				 (SELECT Defensebase FROM ENTITE WHERE Nom = NEW.Nom) * 
				 (SELECT qte FROM ObjetAchete WHERE NomObjet IN (SELECT NomObjet FROM OBJET WHERE TypeObjet = 'Augmente_Def')))
	WHERE LettreType = 'A' AND Nom = NEW.Nom;
	UPDATE COMBAT
	SET Attaque = (SELECT Attaquebase FROM ENTITE WHERE Nom = NEW.Nom) + 
					((SELECT Effet FROM OBJET WHERE TypeObjet = 'Augmente_Atk') * 
					(SELECT Attaquebase FROM ENTITE WHERE Nom = NEW.Nom) * 
					(SELECT qte FROM ObjetAchete WHERE NomObjet IN (SELECT NomObjet FROM OBJET WHERE TypeObjet = 'Augmente_Atk')))
	WHERE LettreType = 'A' AND Nom = NEW.Nom;
END;

DROP TRIGGER IF EXISTS CheckSkill;
CREATE TRIGGER CheckSkill
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

DROP TRIGGER IF EXISTS ActiverSkillOffensif;
CREATE TRIGGER ActiverSkillOffensif
AFTER INSERT ON ChoixSkill
WHEN (SELECT COUNT(*) FROM COMBAT) > 0 AND NEW.SkillChoisi IN (SELECT NomSkill FROM SKILL WHERE TypeSkill = "Offensif")
BEGIN
	UPDATE COMBAT
	SET PVactuels = ROUND(PVactuels - ((((SELECT EffetSkill FROM SKILL WHERE NomSkill = NEW.SkillChoisi) 											--1.0 ou 1.1 ou 1.2
	* (SELECT SUM(Attaque) FROM COMBAT WHERE Nom IN (SELECT Nom FROM PersoPossede)))) 																--35+...
	- MIN((SELECT SUM(Attaque) FROM COMBAT WHERE Nom IN (SELECT Nom FROM PersoPossede)), ((SELECT Defense FROM COMBAT WHERE LettreType = 'M')/2)))	--MIN(35+...,(DefenseAdverse/2))
	*(SELECT ((RANDOM() / 9223372036854775808.0) + 5) /5)) 																							--Ce random vaut entre 0.8 et 1.2
	WHERE LettreType = 'M';
END;

DROP TRIGGER IF EXISTS ActiverSkillSoin;
CREATE TRIGGER ActiverSkillSoin
AFTER INSERT ON ChoixSkill
WHEN (SELECT COUNT(*) FROM COMBAT) > 0 AND NEW.SkillChoisi IN (SELECT NomSkill FROM SKILL WHERE TypeSkill = "Soin")
BEGIN
	UPDATE COMBAT
	SET PVactuels = ROUND(PVactuels + (ROUND((SELECT EffetSkill FROM SKILL WHERE NomSkill = NEW.SkillChoisi) * (SELECT ((RANDOM() / 9223372036854775808.0) + 5) /5)))*1.5)
	WHERE LettreType = 'A';
	UPDATE COMBAT
	SET PVactuels = ROUND(PVactuels + (ROUND((SELECT EffetSkill FROM SKILL WHERE NomSkill = NEW.SkillChoisi) - 20)/5) * (SELECT ((RANDOM() / 9223372036854775808.0) + 5) /5))
	WHERE LettreType = 'M';
END;

DROP TRIGGER IF EXISTS ContreAttaqueEnnemi;
CREATE TRIGGER ContreAttaqueEnnemi
AFTER UPDATE OF PVactuels ON COMBAT
FOR EACH ROW
WHEN new.LettreType = 'M'
BEGIN
	UPDATE COMBAT
	SET PVactuels = ROUND(PVactuels - ((((SELECT EffetSkill FROM SKILL WHERE NomSkill IN (SELECT NomSkill FROM SkillEntite WHERE Nom IN (SELECT Nom FROM COMBAT WHERE LettreType = 'M') ORDER BY RANDOM() LIMIT 1))
	* (SELECT SUM(Attaque) FROM COMBAT WHERE LettreType = 'M'))) 																
	- MIN((SELECT SUM(Attaque) FROM COMBAT WHERE LettreType = 'M'), ((SELECT Defense FROM COMBAT WHERE LettreType = 'A')/2)))	
	*(SELECT ((RANDOM() / 9223372036854775808.0) + 5) /5)) 																							
	WHERE LettreType = 'A';
END;
	
DROP TRIGGER IF EXISTS CheckPVNegatif;
CREATE TRIGGER CheckPVNegatif
AFTER UPDATE ON COMBAT
WHEN (SELECT COUNT(*) PVactuels FROM COMBAT WHERE PVactuels < 0) > 0
BEGIN
	UPDATE COMBAT
	SET PVactuels = 0
	WHERE PVactuels < 0;
END;

DROP TRIGGER IF EXISTS DeleteCombatRow;
CREATE TRIGGER DeleteCombatRow
AFTER UPDATE OF PVactuels ON COMBAT
FOR EACH ROW
WHEN NEW.PVactuels = 0
BEGIN
  DELETE FROM COMBAT WHERE ROWID = NEW.ROWID;
END;

DROP TRIGGER IF EXISTS EnnemiMort;
CREATE TRIGGER EnnemiMort
AFTER UPDATE OF PVactuels ON COMBAT
FOR EACH ROW
WHEN NEW.PVactuels = 0 AND NEW.LettreType = 'M'
BEGIN
	UPDATE JOUEUR
	SET ArgentJoueur = ArgentJoueur + (SELECT ArgentDrop FROM Monstre WHERE Nom = NEW.Nom)
	WHERE (SELECT COUNT(*) FROM COMBAT WHERE LettreType = 'M' AND PVactuels = 0) = (SELECT COUNT(*) FROM COMBAT WHERE LettreType = 'M');
END;

DROP TRIGGER IF EXISTS DefaiteV3;
CREATE TRIGGER DefaiteV3
AFTER DELETE ON COMBAT
FOR EACH ROW
WHEN (SELECT COUNT(*) FROM COMBAT WHERE LettreType = 'M') = (SELECT COUNT(*) FROM COMBAT) 
AND (SELECT COUNT(*) FROM COMBAT) > 0
BEGIN
	DELETE FROM COMBAT;
	DELETE FROM ChoixSkill;
	UPDATE JOUEUR
	SET ArgentJoueur = NULL;
END;

DROP TRIGGER IF EXISTS CheckPVMax;
CREATE TRIGGER CheckPVMax
AFTER UPDATE ON COMBAT
FOR EACH ROW
BEGIN
	UPDATE COMBAT
	SET PVactuels = ((SELECT PVMaxbase FROM ENTITE WHERE Nom = NEW.Nom) + 
				 ((SELECT Effet FROM OBJET WHERE TypeObjet = 'Augmente_Vie') * 
				 (SELECT PVMaxbase FROM ENTITE WHERE Nom = NEW.Nom) * 
				 (SELECT qte FROM ObjetAchete WHERE NomObjet IN (SELECT NomObjet FROM OBJET WHERE TypeObjet = 'Augmente_Vie'))))
	WHERE PVactuels > ((SELECT PVMaxbase FROM ENTITE WHERE Nom = NEW.Nom) + 
				 ((SELECT Effet FROM OBJET WHERE TypeObjet = 'Augmente_Vie') * 
				 (SELECT PVMaxbase FROM ENTITE WHERE Nom = NEW.Nom) * 
				 (SELECT qte FROM ObjetAchete WHERE NomObjet IN (SELECT NomObjet FROM OBJET WHERE TypeObjet = 'Augmente_Vie'))))
	AND Nom = NEW.Nom;
END;

/* ========================= FIN TRIGGERS ========================= */

/* ========================= DEBUT VUES ========================= */

DROP VIEW IF EXISTS Inventaire;
CREATE VIEW Inventaire("Nom objet", "Quantité", "Type", "Boost (en %)") AS
SELECT ObjetAchete.NomObjet, ObjetAchete.qte, OBJET.TypeObjet, OBJET.Effet * ObjetAchete.qte * 100
FROM ObjetAchete, OBJET
WHERE ObjetAchete.NomObjet = OBJET.NomObjet;

DROP VIEW IF EXISTS SkillsUtilisables;
CREATE VIEW SkillsUtilisables AS
SELECT DISTINCT SkillEntite.NomSkill
FROM SkillEntite, PersoPossede
WHERE PersoPossede.Nom = SkillEntite.Nom;

DROP VIEW IF EXISTS StatsEquipeBase;
CREATE VIEW StatsEquipeBase("Nom", "PV Max brutes", "Attaque brute", "Défense brute") AS
SELECT ENTITE.Nom, ENTITE.PVMaxbase, ENTITE.Attaquebase, ENTITE.Defensebase
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
    ("Bertrand", 200, 35, 20, 'A'),
    ("Roseline", 150, 45, 15, 'A'),
    ("Igor", 350, 20, 45, 'A'),
    ("Giselle", 400, 50, 50, 'A'),
    
    ("Loup", 100, 30, 5, 'M'),
    ("Ogre", 200, 40, 15, 'M'),
    ("Gobelin", 70, 55, 3, 'M'),
    ("Blob", 50, 10, 0, 'M'),
    ("Ours", 150, 50, 20, 'M'),
    ("Sirene", 100, 50, 10, 'M'),
    ("Dragon", 400, 250, 90, 'M'),
    ("Cyclope", 250, 100, 70, 'M');

INSERT INTO JOUEUR VALUES
    ("Player", 100);

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
SELECT *
FROM ENTITE
WHERE LettreType = 'M'
ORDER BY RANDOM()
LIMIT 1;

=== Choisir une attaque en combat ===
DELETE FROM ChoixSkill;
INSERT INTO ChoixSkill(SkillChoisi) 
VALUES ("[Nom du skill]");

=== Achat de perso ===
INSERT INTO PersoPossede VALUES
	("Player","[Nom du perso]");
	
=== Acheter/vendre un objet ===
UPDATE ObjetAchete
SET qte = [Nouvelle quantité]
WHERE NomObjet = "[Nom de l'objet]";

=== Voir stats de perso ===
SELECT * FROM ENTITE
WHERE Nom = "[Nom du perso]";
 
=== Voir argent ===
SELECT ArgentJoueur FROM JOUEUR
WHERE NomJoueur = "[Nom du joueur]";

=== Voir les persos possédés ===
SELECT NOM FROM PersoPossede;

=== Voir skills utilisables ===
SELECT * FROM SkillsUtilisables;

=== Voir inventaire ===
SELECT * FROM Inventaire;

=== Voir stats brutes de l'équipe ===
SELECT * FROM StatsEquipe;
*/
