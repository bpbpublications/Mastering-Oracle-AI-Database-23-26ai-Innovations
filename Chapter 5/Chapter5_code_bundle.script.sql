-- GraphQL 

---- Create and populate projects and team_members tables with demo entries:

CREATE TABLE projects (
  project_id NUMBER(2) CONSTRAINT pk_projects PRIMARY KEY,
  project_name VARCHAR2(50),
  location VARCHAR2(50));
CREATE TABLE team_members (
  member_id NUMBER(4) CONSTRAINT pk_team_members PRIMARY KEY,
  full_name VARCHAR2(50),
  role VARCHAR2(20),
  supervisor_id NUMBER(4),
  join_date DATE,
  monthly_pay NUMBER(10,2),
  bonus NUMBER(10,2),
  project_id NUMBER(2) CONSTRAINT fk_project REFERENCES projects);
INSERT INTO projects VALUES (1, 'Apollo Initiative', 'San Diego');
INSERT INTO projects VALUES (2, 'Neptune AI', 'Austin');
INSERT INTO projects VALUES (3, 'Orion Cloud', 'Chicago');
INSERT INTO projects VALUES (4, 'Luna Security', 'Boston');


INSERT INTO team_members VALUES (1010, 'Jenna Cole', 'Developer', 1020, TO_DATE('2022-03-12', 'YYYY-MM-DD'), 7200, 500, 1);
INSERT INTO team_members VALUES (1011, 'Marco Lee', 'Tester', 1020, TO_DATE('2021-11-25', 'YYYY-MM-DD'), 6500, NULL, 1);
INSERT INTO team_members VALUES (1012, 'Priya Das', 'DevOps Engineer', 1021, TO_DATE('2023-01-08', 'YYYY-MM-DD'), 8000, 1000, 2);
INSERT INTO team_members VALUES (1013, 'Kenny Yu', 'Architect', NULL, TO_DATE('2020-06-17', 'YYYY-MM-DD'), 9500, NULL, 2);
INSERT INTO team_members VALUES (1014, 'Rachel Ng', 'UI Designer', 1013, TO_DATE('2021-07-01', 'YYYY-MM-DD'), 6900, 200, 2);
INSERT INTO team_members VALUES (1015, 'Luis Fernandez', 'PM', NULL, TO_DATE('2019-09-14', 'YYYY-MM-DD'), 10500, 1500, 3);
INSERT INTO team_members VALUES (1016, 'Tina Brooks', 'Security Analyst', 1015, TO_DATE('2020-02-29', 'YYYY-MM-DD'), 7800, NULL, 4);

COMMIT;

---- Create an index on a foreign key

CREATE INDEX idx_team_project ON team_members(project_id);

---- Retrieve data using GraphQL table function 

SELECT * FROM graphql('
 projects
 {
  projectId    : project_id
  projectName  : project_name
  location     : location
 }');


---- Execute the similar query on the team_members table

set long 200000

set pagesize 100

SELECT * FROM graphql('
team_members
{
  memberId     : member_id
  fullName     : full_name
  role         : role
  monthlyPay   : monthly_pay
  joinDate     : join_date
}');


---- Join tables

set long 200000

SELECT * FROM graphql('
project : projects
{
projectId     : project_id
projectName   : project_name
location      : location
teamMembers   : team_members 
  [{
    memberId     : member_id
    fullName     : full_name
    role         : role
    monthlyPay   : monthly_pay
  }]
}');

---- Unnest the data 

set long 200000

SELECT * FROM graphql('
 members : team_members
{
 memberId     : member_id
 fullName     : full_name
 role         : role
 monthlyPay   : monthly_pay
   projects @unnest
    {
      projectName : project_name
    }
 }');


-- JSON collections

----  Create a JSON collection table called bookshelf:

CREATE JSON COLLECTION TABLE bookshelf;

----  Insert a new document (an _id will be automatically generated):

INSERT INTO bookshelf (data)
VALUES (JSON('{"title": "1984", "author": "George Orwell", "copies": 4}'));

commit;

---- Query documents with pretty formatting:

SELECT JSON_SERIALIZE(data PRETTY)
FROM bookshelf;

----  Insert another document with a custom _id:

INSERT INTO bookshelf (data)
VALUES (JSON('{
  "_id": "book001",
  "title": "Brave New World",
 "author": "Aldous Huxley",
  "copies": 3
}'));

commit;


---- Create a table with ETAG support

CREATE JSON COLLECTION TABLE bookshelf WITH ETAG;

----  Insert a new document (an _id will be automatically generated):

INSERT INTO bookshelf (data)
VALUES (JSON('{"title": "1984", "author": "George Orwell", "copies": 4}'));

COMMIT;


----  Query documents with pretty formatting 

SELECT JSON_SERIALIZE(data PRETTY)
FROM bookshelf;


---- Use etag for safe updates (optimistic locking)


UPDATE bookshelf b
SET data = JSON('{
  "_metadata": {
    "etag": "55D5712F003E3026E0630500000A484B"
  },
  "title": "1984",
  "author": "George Orwell",
  "copies": 5
}')
WHERE b.data."_id".string() = '67fe9b570f484b30262f003d'
 AND b.data."_metadata"."etag".string() = '55D5712F003E3026E0630500000A484B';


-- JSON Array

----  Create books table

CREATE TABLE books (
  book_id   NUMBER PRIMARY KEY,
  title     VARCHAR2(100),
  author    VARCHAR2(100)
);


---- Create reviews table

CREATE TABLE reviews (
  review_id  NUMBER PRIMARY KEY,
  book_id    NUMBER REFERENCES books(book_id),
  reviewer   VARCHAR2(100),
  rating     NUMBER(1)
);


----- Insert sample data

INSERT INTO books (book_id, title, author) VALUES (1, 'To Kill a Mockingbird', 'Harper Lee');

-- Insert into reviews
INSERT INTO reviews (review_id, book_id, reviewer, rating) VALUES (101, 1, 'Alice', 5);
INSERT INTO reviews (review_id, book_id, reviewer, rating) VALUES (102, 1, 'Bob', 4);

COMMIT;


----  Query a JSON object for a book, including an array of its reviews

SELECT JSON_SERIALIZE(
         JSON_OBJECT(
           'book-title' : b.title,
           'author'     : b.author,
           'reviews'    : JSON_ARRAY(
             SELECT JSON_OBJECT(
               'reviewer' : r.reviewer,
               'rating'   : r.rating
             )
             FROM reviews r
             WHERE r.book_id = b.book_id
           )
         )
         PRETTY
       ) AS output
FROM books b
WHERE b.book_id = 1;


-- Optimizing JSON Performance

---- Create a table with a column of JSON data type

CREATE TABLE json_table (
  id   NUMBER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
  data JSON
);


---- Insert demo data into previously created table:

insert into json_table columns(data) 
values(
          json_object(
              'name' value 'Salome',
              'age' value 12,
              'city' value 'Tbilisi'));
commit;


---- Create a search index on data column

CREATE SEARCH INDEX mk_search_idx ON json_table columns(data) FOR JSON;

---- Add more row with array

INSERT INTO json_table COLUMNS(data)
VALUES (
  JSON_OBJECT(
    'name' VALUE 'Salome',
    'age' VALUE 12, 
    'city' VALUE 'Tbilisi',
    'hobbies' VALUE JSON_ARRAY('reading', 'singing', 'drawing')
    ));


---- Indexing the elements inside the hobbies array

CREATE MULTIVALUE INDEX mk_hobbies_idx ON json_table t (t.data.hobbies.string());

---- Create an index on the lowercase version of the name

CREATE INDEX idx_lower_name 
ON json_table t (LOWER(JSON_VALUE(t.data, '$.name')));


---- This index will help with queries like this:

SELECT * 
       FROM json_table 
       WHERE LOWER(JSON_VALUE(data, '$.name')) = 'salome';


---- Let’s see that index in the explain plan:

EXPLAIN PLAN FOR SELECT * FROM json_table
            WHERE LOWER(JSON_VALUE(data, '$.name')) = 'salome';


---- Select statement

SELECT plan_table_output 
           FROM table(dbms_xplan.display('plan_table',null,'basic'));


-- In-Memory JSON Data

CREATE TABLE json_table_inmem (
  id   NUMBER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
  data JSON
)
INMEMORY;  


-- Partitioning JSON Collection Tables

CREATE TABLE json_orders (
   id   NUMBER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
   data JSON,
   order_date_vc DATE)
  PARTITION BY RANGE (order_date_vc) (
  PARTITION p_2023 VALUES LESS THAN (TO_DATE('2024-01-01', 'YYYY-MM-DD')),
  PARTITION p_2024 VALUES LESS THAN (TO_DATE('2025-01-01', 'YYYY-MM-DD')));





