-- Fugue graph schema for SurrealDB
-- Usage: surreal import --conn http://localhost:8000 --ns fugue --db graph priv/surrealdb/schema.surql

-- Article table
DEFINE TABLE article SCHEMAFULL;
DEFINE FIELD title ON article TYPE string;
DEFINE FIELD abstract ON article TYPE option<string>;
DEFINE FIELD is_disambiguation ON article TYPE bool DEFAULT false;
DEFINE FIELD timestamp ON article TYPE option<string>;
DEFINE FIELD in_degree ON article TYPE int DEFAULT 0;
DEFINE FIELD out_degree ON article TYPE int DEFAULT 0;
DEFINE FIELD pagerank ON article TYPE float DEFAULT 0.0;

-- Full-text search index on title
DEFINE ANALYZER article_analyzer TOKENIZERS blank, class FILTERS lowercase, ascii;
DEFINE INDEX article_title_search ON article FIELDS title SEARCH ANALYZER article_analyzer BM25;

-- Category table
DEFINE TABLE category SCHEMAFULL;
DEFINE FIELD name ON category TYPE string;

-- Edge: article -[links_to]-> article
DEFINE TABLE links_to SCHEMAFULL TYPE RELATION FROM article TO article;
DEFINE FIELD link_type ON links_to TYPE string DEFAULT "LINKS_TO";

-- Edge: article -[categorized_as]-> category
DEFINE TABLE categorized_as TYPE RELATION FROM article TO category;
