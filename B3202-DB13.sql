-- lien Ryori
create database link lienRyori
connect to abellahbib identified by B3202
using 'DB11';

-- test
select *
from Ryori.Clients@lienRyori;

-- lien DB12
create database link lienDB12
connect to abellahbib identified by B3202
using 'DB12';

-- lien DB14
create database link lienDB14
connect to abellahbib identified by B3202
using 'DB14';

-- création fragments
create table Produits
as (select *
  from Ryori.Produits@lienRyori);
  
-- test
select * from Produits;

create table Categories
as (select *
  from Ryori.Categories@lienRyori);
  
create table Clients_ES
as (select *
  from Ryori.Clients@lienRyori
  where pays='Espagne' or pays='Portugal' or pays='Andorre' or pays='France' or pays='Gibraltar' or pays='Italie'
  or pays='Saint-Marin' or pays='Vatican' or pays='Malte' or pays='Albanie' or pays='Bosnie-Herzégovine' or pays='Croatie' or pays='Grèce'
  or pays='Macédoine' or pays='Monténégro' or pays='Serbie' or pays='Slovénie' or pays='Bulgarie');
  
create table Stock_ES
as (select *
  from Ryori.Stock@lienRyori
  where pays='Espagne' or pays='Portugal' or pays='Andorre' or pays='France' or pays='Gibraltar' or pays='Italie'
  or pays='Saint-Marin' or pays='Vatican' or pays='Malte' or pays='Albanie' or pays='Bosnie-Herzégovine' or pays='Croatie' or pays='Grèce'
  or pays='Macédoine' or pays='Monténégro' or pays='Serbie' or pays='Slovénie' or pays='Bulgarie');

create table Commandes_ES
as (select co.*
  from Ryori.Commandes@lienRyori co, Clients_ES
  where co.CODE_CLIENT=Clients_ES.CODE_CLIENT);
  
create table Details_Commandes_ES
as (select dc.*
  from Ryori.Details_Commandes@lienRyori dc, Commandes_ES
  where dc.NO_COMMANDE=Commandes_ES.NO_COMMANDE);
  
-- droits d'accès
grant select on Categories to mchevalier;
grant select on Categories to rfolgoas;
grant select on Produits to mchevalier;
grant select on Produits to rfolgoas;
grant select on Clients_ES to mchevalier;
grant select on Clients_ES to rfolgoas;
grant select on Stock_ES to mchevalier;
grant select on Stock_ES to rfolgoas;
grant select on Commandes_ES to mchevalier;
grant select on Commandes_ES to rfolgoas;
grant select on Details_Commandes_ES to mchevalier;
grant select on Details_Commandes_ES to rfolgoas;

--contraintes d'integrité

--clés primaires
alter table Categories add constraint pkCategories primary key (Code_Categorie);
alter table Clients_ES add constraint pkClients_ES primary key (Code_Client);
alter table Commandes_ES add constraint pkCommandes_ES primary key (No_Commande);
alter table Details_Commandes_ES add constraint pkDetails_Commandes_ES primary key (No_Commande, Ref_Produit);
alter table Produits add constraint pkProduits primary key (Ref_Produit);
alter table Stock_ES add constraint pkStock_ES primary key (Ref_Produit, Pays);

--clés étrangères
alter table Commandes_ES add constraint fkCommandes_ES foreign key (Code_Client) references Clients_ES;
alter table Details_Commandes_ES add constraint fkCommandes_ES_1 foreign key (No_Commande) references Commandes_ES;
alter table Details_Commandes_ES add constraint fkCommandes_ES_2 foreign key (Ref_Produit) references Produits;
alter table Produits add constraint fkProduits foreign key (Code_Categorie) references Categories;
alter table Stock_ES add constraint fkStock_ES foreign key (Ref_produit) references Produits;


-- triggers
-- trigger sur INSERT et UPDATE on Stock_ES
-- vérifie l’existence des produits

-- Contrainte de clé étrangère
-- vérifie que la le no_employe dans une commande soit bien dans la table employe
create or replace trigger checkEmploye
before insert or update on Commandes_ES
for each row
declare
  counter$ number(8);
begin
  select count(*) into counter$
  from mchevalier.Employes@lienDB14
  where No_Employe = :new.No_Employe;
  if(counter$ = 0) then
    raise_application_error(-20001, 'No_Employe n’existe pas dans la table Employe');
  end if;
end;
/

-- test
select * from mchevalier.Employes@lienDB14;
insert into Commandes_ES (No_Commande, Code_Client, No_Employe, Date_Commande) values (000000, 'MAGAA', 999999, DATE '2012-12-10');


-- Contrainte de clé étrangère
-- vérifie que la le no_fournisseur dans un produit soit bien dans la table fournisseurs
create or replace trigger checkFournisseur
before insert or update on Produits
for each row
declare
  counter$ number(8);
begin
  select count(*) into counter$
  from rfolgoas.Fournisseurs@lienDB12
  where No_Fournisseur = :new.No_Fournisseur;
  if(counter$ = 0) then
    raise_application_error(-20002, 'No_Fournisseur n’existe pas dans la table Fournisseurs');
  end if;
end;
/

-- test
select * from rfolgoas.Fournisseurs@lienDB12;
insert into Produits values (999999, 'Poulet', 999999, 1, '3 kilos', 5);


-- Contrainte de clé étrangère
-- Pour ne pas pouvoir modifier ou supprimer  un produits dont le ref_produit existe dans un stock OU dans un details_commandes
create or replace trigger checkStockEtDetailsCommandes
before delete or update on Produits
for each row
declare
  counter$ number(8);
begin
  select count(*) into counter$
  from rfolgoas.Stock_EN@lienDB12 sen, rfolgoas.Stock_Autres@lienDB12 sau, rfolgoas.Details_Commandes_EN@lienDB12 dcen, rfolgoas.Details_Commandes_Autres@lienDB12 dcau, mchevalier.Stock_A@lienDB14 sa, mchevalier.Details_Commandes_A@lienDB14 dca
  where sen.Ref_Produit = :old.Ref_Produit or sau.Ref_Produit = :old.Ref_Produit or dcen.Ref_Produit = :old.Ref_Produit
    or dcau.Ref_Produit = :old.Ref_Produit or sa.Ref_Produit = :old.Ref_Produit or dca.Ref_Produit = :old.Ref_Produit;
  if(counter$ > 0) then
    raise_application_error(-20003, 'L’ancien Ref_produit est présent dans Stock ou Details_Commandes');
  end if;
end;
/

-- mettre contraintes sur les pays lors d'insertion or update

alter table Clients_ES
add constraint ck_Pays_Clients
check (pays='Espagne' or pays='Portugal' or pays='Andorre' or pays='France' or pays='Gibraltar' or pays='Italie'
  or pays='Saint-Marin' or pays='Vatican' or pays='Malte' or pays='Albanie' or pays='Bosnie-Herzégovine' or pays='Croatie' or pays='Grèce'
  or pays='Macédoine' or pays='Monténégro' or pays='Serbie' or pays='Slovénie' or pays='Bulgarie');

alter table Stock_ES
add constraint ck_Pays_Stock
check (pays='Espagne' or pays='Portugal' or pays='Andorre' or pays='France' or pays='Gibraltar' or pays='Italie'
  or pays='Saint-Marin' or pays='Vatican' or pays='Malte' or pays='Albanie' or pays='Bosnie-Herzégovine' or pays='Croatie' or pays='Grèce'
  or pays='Macédoine' or pays='Monténégro' or pays='Serbie' or pays='Slovénie' or pays='Bulgarie');

-- création des vues
create or replace view Clients as (
  select * from Clients_ES
  union all
  select * from rfolgoas.Clients_EN@liendb12
  union all
  select * from mchevalier.Clients_A@liendb14
  union all
  select * from rfolgoas.Clients_Autres@liendb12);
  
-- optimisation
create or replace view Clients as (
  select * from Clients_ES
  union all
  select * from rfolgoas.Clients_EN@liendb12
  union all
  select * from mchevalier.Clients_A@liendb14
  union all
  select * from rfolgoas.Clients_Autres@liendb12);
  
create or replace view Clients as (

select * from Clients_ES where pays in ('Espagne', 'Portugal', 'Andorre', 'France', 'Gibraltar', 'Italie', 'Saint-Marin', 'Vatican', 'Malte', 'Albanie', 'Bosnie-Herzegovine', 'Croatie', 'Grece', 'Macedoine', 'Montenegro', 'Serbie', 'Slovenie', 'Bulgarie')

  union all

select * from Clients_EN where pays in ('Norvege','Suede','Danemark','Islande','Finlande','Royaume-Uni','Irlande','Belgique', 'Luxembourg','Pays-Bas','Allemagne','Pologne')

  union all

select * from Clients_A where pays in ('Antigua-et-Barbuda', 'Argentine', 'Bahamas', 'Barbade', 'Belize','Bolivie', 'Bresil','Canada', 'Chili', 'Colombie', 'Costa Rica', 'Cuba', 'Republique dominicaine', 'Dominique',
'Equateur', 'Etats-Unis', 'Grenade', 'Guatemala', 'Guyana', 'Haiti', 'Honduras', 'Jamaique','Mexique', 'Nicaragua', 'Panama', 'Paraguay', 'Perou', 'Saint-Christophe-et-Nieves', 'Sainte-Lucie', 'Saint-Vincent-et-les Grenadines', 
'Salvador', 'Suriname', 'Trinite-et-Tobago','Uruguay','Venezuela')

  union all

select * from Clients_Autres where pays not in ('Norvege','Suede','Danemark','Islande','Finlande','Royaume-Uni','Irlande'
,'Belgique','Luxembourg','Pays-Bas','Allemagne','Pologne','Espagne', 'Portugal', 'Andorre', 'France', 'Gibraltar', 'Italie', 'Saint-Marin', 'Vatican', 'Malte', 'Albanie', 'Bosnie-Herzegovine', 'Croatie', 'Grece', 'Macedoine',
'Montenegro', 'Serbie', 'Slovenie', 'Bulgarie','Antigua-et-Barbuda', 'Argentine', 'Bahamas', 'Barbade', 'Belize','Bolivie', 'Bresil','Canada', 'Chili', 'Colombie', 'Costa Rica', 'Cuba', 'Republique dominicaine', 'Dominique',
'Equateur', 'Etats-Unis', 'Grenade', 'Guatemala', 'Guyana', 'Haiti', 'Honduras', 'Jamaique','Mexique', 'Nicaragua', 'Panama', 'Paraguay', 'Perou', 'Saint-Christophe-et-Nieves', 'Sainte-Lucie', 'Saint-Vincent-et-les Grenadines', 
'Salvador', 'Suriname', 'Trinite-et-Tobago','Uruguay','Venezuela')
);


create or replace view Stock as (
  select * from Stock_ES
  union all
  select * from rfolgoas.Stock_EN@liendb12
  union all
  select * from mchevalier.Stock_A@liendb14
  union all
  select * from rfolgoas.Stock_Autres@liendb12);
  
  create or replace view Stock as (

select * from Stock_ES where pays in ('Espagne', 'Portugal', 'Andorre', 'France', 'Gibraltar', 'Italie', 'Saint-Marin', 'Vatican', 'Malte', 'Albanie', 'Bosnie-Herzegovine', 'Croatie', 'Grece', 'Macedoine', 'Montenegro', 'Serbie', 'Slovenie', 'Bulgarie')

  union all

select * from Stock_EN where pays in ('Norvege','Suede','Danemark','Islande','Finlande','Royaume-Uni','Irlande','Belgique', 'Luxembourg','Pays-Bas','Allemagne','Pologne')

  union all

select * from Stock_A where pays in ('Antigua-et-Barbuda', 'Argentine', 'Bahamas', 'Barbade', 'Belize','Bolivie', 'Bresil','Canada', 'Chili', 'Colombie', 'Costa Rica', 'Cuba', 'Republique dominicaine', 'Dominique',
'Equateur', 'Etats-Unis', 'Grenade', 'Guatemala', 'Guyana', 'Haiti', 'Honduras', 'Jamaique','Mexique', 'Nicaragua', 'Panama', 'Paraguay', 'Perou', 'Saint-Christophe-et-Nieves', 'Sainte-Lucie', 'Saint-Vincent-et-les Grenadines', 
'Salvador', 'Suriname', 'Trinite-et-Tobago','Uruguay','Venezuela')

  union all

select * from Stock_Autres where pays not in ('Norvege','Suede','Danemark','Islande','Finlande','Royaume-Uni','Irlande'
,'Belgique','Luxembourg','Pays-Bas','Allemagne','Pologne','Espagne', 'Portugal', 'Andorre', 'France', 'Gibraltar', 'Italie', 'Saint-Marin', 'Vatican', 'Malte', 'Albanie', 'Bosnie-Herzegovine', 'Croatie', 'Grece', 'Macedoine',
'Montenegro', 'Serbie', 'Slovenie', 'Bulgarie','Antigua-et-Barbuda', 'Argentine', 'Bahamas', 'Barbade', 'Belize','Bolivie', 'Bresil','Canada', 'Chili', 'Colombie', 'Costa Rica', 'Cuba', 'Republique dominicaine', 'Dominique',
'Equateur', 'Etats-Unis', 'Grenade', 'Guatemala', 'Guyana', 'Haiti', 'Honduras', 'Jamaique','Mexique', 'Nicaragua', 'Panama', 'Paraguay', 'Perou', 'Saint-Christophe-et-Nieves', 'Sainte-Lucie', 'Saint-Vincent-et-les Grenadines', 
'Salvador', 'Suriname', 'Trinite-et-Tobago','Uruguay','Venezuela')
);

create or replace view Commandes as (
  select * from Commandes_ES
  union all
  select * from rfolgoas.Commandes_EN@liendb12
  union all
  select * from mchevalier.Commandes_A@liendb14
  union all
  select * from rfolgoas.Commandes_Autres@liendb12);

create or replace view Details_Commandes as (
  select * from Details_Commandes_ES
  union all
  select * from rfolgoas.Details_Commandes_EN@liendb12
  union all
  select * from mchevalier.Details_Commandes_A@liendb14
  union all
  select * from rfolgoas.details_commandes_Autres@liendb12);

create or replace view Fournisseurs as (
  select * from rfolgoas.Fournisseurs@lienDB12);
  
create or replace view Employes as (
  select * from mchevalier.Employes@lienDB14);
  
-- tests
select * from Clients
where pays='Allemagne' or pays='Etats-Unis' or pays='Italie' or pays='Suisse';

select * from Clients;

-- tests a faire



-- enlever lien DB11 pour faire les tests
drop database link lienRyori;

-- Réplication Fournisseurs et Employes
create materialized view DMV_Fournisseurs 
refresh fast
next sysdate + (3/24/60)
as (
  select * from rfolgoas.Fournisseurs@lienDB12 );
  
select * from DMV_Fournisseurs where No_Fournisseur = 30;

create materialized view DMV_Employes
refresh complete
next sysdate + (3/24/60)
as (
  select * from mchevalier.Employes@lienDB14 );
  

select * from mchevalier.MLOG$_Employes@lienDB14;
select * from DMV_Employes; where No_Employe = 8;

-- contraintes sur réplicas
alter table DMV_Fournisseurs add constraint pkFournisseurs primary key (no_Fournisseur);
alter table Clients_ES add constraint pkClients_ES primary key (Code_Client);
  
-- Logs
create materialized view log on Produits;
-- nom de la table crée : MLOG$_Produits
grant select on MLOG$_Produits to rfolgoas;
grant select on MLOG$_Produits to mchevalier;

select No_Commande, Code_Client, Adresse, Ville, Code_Postal, No_Employe, Date_Commande, Date_Envoi, Ref_Produit from Clients natural join Commandes natural join Details_Commandes where pays = 'France';

drop materialized view DMV_Fournisseurs;

select * from DMV_Employes;

select * from Clients;

  
  
  
  
  
  
  
  
  