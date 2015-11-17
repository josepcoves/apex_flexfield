# Relational: Flexfield plugin

The aim of this plugin is to provide dynamic item types which will be loaded at plugin runtime. For people who worked with Oracle eBusinessSuite I developed a similar idea which could fit perfectly with their own EBS flexfields.

##Requisites to use:

An existing data base table with N flexfield fields of varchar2(4000) to fill
- Optional: flexfield metadata table (FLEXFIELD_DEF, see example below)
- This plugin on some page

##Case of use

Some applications leave administrators the capability of extending its application by adding some fields to existing tables. In that case, administrator can expand application functionality by storing some data to application without the need of technical assistance.
Imagine you have your business table of products

###PRODUCTS

You can define N flexfield items which application administrator will define:

PRODUCTS:
- FLEXFIELD_001 (varchar2(4000))
- FLEXFIELD_002 (varchar2(4000))
- ...
- FLEXFIELD_NNN (varchar2(4000))

Then you need a parametrization table for flexfield metadata, for instance:

###FLEXFIELD_DEF:
```sql 
CREATE SEQUENCE FLEXFIELD_DEF_SEQ
/
CREATE TABLE  "FLEXFIELD_DEF" 
   (	"ID" NUMBER NOT NULL ENABLE, 
	"SOURCE_TABLE" VARCHAR2(200) NOT NULL ENABLE, 
	"SOURCE_COLUMN" VARCHAR2(200) NOT NULL ENABLE, 
	"ACTIVE" CHAR(1) DEFAULT 'S' NOT NULL ENABLE, 
	"NAME" VARCHAR2(200) NOT NULL ENABLE, 
	"DESCRIPTION" VARCHAR2(2000), 
	"TYPE" VARCHAR2(20) DEFAULT 'TEXT' NOT NULL ENABLE, 
	"LOV" VARCHAR2(200), 
	"CREATION_DATE" DATE, 
	"CREATED_BY" VARCHAR2(240), 
	"LAST_UPDATE_DATE" DATE, 
	"LAST_UPDATED_BY" VARCHAR2(240), 
	"NULLABLE" CHAR(1) DEFAULT 'S', 
	"FLEX_SIZE" NUMBER, 
	"MAX_LENGTH" NUMBER, 
	"HEIGHT" NUMBER, 
	"HTML_ATTRIBUTES" VARCHAR2(4000), 
	"LOV_SQL" VARCHAR2(4000), 
	 CONSTRAINT "FLEXFIELD_DEF_CON_TYPES" CHECK ( "TYPE" in ('LOV','BFLOV','STRING','STATIC','TEXTAREA','LOVSQL')) ENABLE, 
	 CONSTRAINT "FLEXFIELD_DEF_PK" PRIMARY KEY ("ID")
  USING INDEX  ENABLE
   )
/

CREATE UNIQUE INDEX  "FLEXFIELD_DEF_UK1" ON  "FLEXFIELD_DEF" ("SOURCE_TABLE", "SOURCE_COLUMN")
/

CREATE OR REPLACE TRIGGER  "FLEXFIELD_DEF_BIU" 
before insert or update on FLEXFIELD_DEF
for each row
declare
  v_cod number;
begin
   if ( inserting ) then
      if (:new.ID is null) then
        select FLEXFIELD_DEF_SEQ.nextval into v_cod from dual;
        :new.ID := v_cod;
      end if;

     
      :new.created_by := 'APEX';
      :new.creation_date := sysdate;
   end if;
   
   if ( updating ) then
  
   :new.last_updated_by := 'APEX';
   :new.last_update_date := sysdate;
   end if;
end;

/
ALTER TRIGGER  "FLEXFIELD_DEF_BIU" ENABLE
/  
```

Then you define a page which uses this plugin by querying previous table. SQL of flexfield plugin:
```sql
SELECT FLEX_NAME
       FLEX_DESCR,
       FLEX_TYPE,
       FLEX_SOURCE,
       'N' FLEX_NULLABLE,
       30 FLEX_SIZE
       null FLEX_MAX_SIZE,
       null FLEX_HEIGHT,
       null FLEX_HTML_ATTRIBUTES
       null LOV_SQL
FROM FLEXFIELD_DEF
WHERE FLEX_NAME = 'MyFlex01' and ACTIVE = 'S'
```

##Some tricks:
- You can dynamically display item label by caching its value via ITEM. For instance, define item plugin label as &P1_ITEM. And inform item value at page value, by reading FLEXFIELD_DEF table.
- Like previous sample, you can dynamically define its column name for a report using previous item &P1_ITEM.
- You can lookup display value for report listing using FLEXFIELD.lookup_display_value(table,column,lov_return_value) (See additional FLEXFIELD package provided)
- If you keep a naming convention for application items like <PREFIX>_TABLE_<FLEX_NUMBER> you can call procedure:  FLEXFIELD.intialize_application_items which will set each application time with its value (See additional FLEXFIELD package provided)
 

##Available item types:
- STRING: Textfield
- TEXTAREA: TextArea
- LOV: Select list (via APEX Lov)
-- Static
-- Dynamic
--- LOVSQL: LOV based on user SQL
--- LOVSQL column must be informed with inner sql

##Example
Select
       FLEX_NAME,        --(varchar2) Flexfield name
       FLEX_DESC,        --(varchar2) Flexfield description -> Shown at help
       FLEX_TYPE,        --(varchar2) STRING, LOV, LOVSQL, TEXTAREA -> Type of flexfield
       FLEX_LOV,         --(varchar2) Name of APEX LOV for LOV type flexfields
       FLEX_NULLABLE,    --(char(1))  S, N -> Specifies if allows null values
       FLEX_SIZE,        --(Integer)  Size of the HTML element
       FLEX_MAX_LENGTH,  --(Integer)  Max length of its content (only for STRING and TEXTAREA types)
       FLEX_HEIGHT,      --(Integer)  Height of HTML element (only for TEXTAREA)
       FLEX_HTML_ATTR,   --(varchar2) Additional HTML element attributes
       FLEX_LOV_SQL      --(varchar2) In case TYPE= LOVSQL this column specifies LOV SQL returning pairs display value and return value
from FLEXFIELD_DEF

where flexfield_name = 'MyField01'

[For more information visit tutorial page](http://goo.gl/934R1T)                          
