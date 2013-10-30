# --- First database schema

# --- !Ups

create sequence        user_seq start with 1;
create sequence        game_seq start with 1;
create sequence      public_seq start with 1;
create sequence association_seq start with 1;

create table users (
  id  bigint
      constraint pk_user
      primary key
      default nextval('user_seq'::regclass),
  
  email     varchar(255) not null,
  name      varchar(255) not null,
  created   timestamp    not null default now(),
  permision int          not null default 0,
  validated boolean      not null default true,
  password  varchar(255) not null
);

create table games (
  id  bigint
      constraint pk_game
      primary key
      default nextval('game_seq'::regclass),
  
  name     varchar(255) not null,
  master   bigint       not null,
  system   varchar(255) not null,
  created  timestamp    not null default now(),
  data     text
);

create table characters (
  id  bigint
      constraint pk_character 
      primary key
      default nextval('public_seq'::regclass),
  
  name     varchar(255) not null,
  created  timestamp    not null default now(),
  user_id  bigint       not null,
  game_id  bigint       not null,
  picture  varchar(255)         ,
  data     text                 ,
  public   boolean
);

create table notes (
  id bigint
     constraint pk_note
     primary key
     default nextval('public_seq'::regclass),
  
  created  timestamp    not null default now(),
  user_id  bigint       not null,
  char_id  bigint       not null,
  content  text         not null,
  public   boolean
);

create table gameAssociation (
  id bigint
     constraint pk_gameassociation
     primary key
     default nextval('association_seq'::regclass),
  
  created  timestamp    not null default now(),
  game_id  bigint       not null,
  user_id  bigint       not null
);

create table characterAssociation (
  id bigint
     constraint pk_characterassocitation
     primary key
     default nextval('association_seq'::regclass),
  
  created  timestamp    not null default now(),
  cida     bigint       not null,
  cidb     bigint       not null
);

alter table games
  add constraint user_game_fk
    foreign key (master)
    references users(id)
  on delete cascade;

alter table characters
  add constraint user_char_fk
    foreign key (user_id)
    references users(id)
  on delete cascade;

alter table characters
  add constraint game_char_fk
    foreign key (game_id)
    references games(id)
  on delete cascade;

alter table notes
  add constraint user_note_fk
    foreign key (user_id)
    references users(id)
  on delete cascade;

alter table notes
  add constraint char_note_fk
    foreign key (char_id)
    references characters(id)
  on delete cascade;

alter table gameAssociation
  add constraint gasso_game_fk
    foreign key (game_id)
    references games(id)
  on delete cascade;

alter table gameAssociation
  add constraint gasso_user_fk
    foreign key (user_id)
    references users(id)
  on delete cascade;

alter table characterAssociation
  add constraint casso_cida_fk
    foreign key (cida)
    references characters(id)
  on delete cascade;

alter table characterAssociation
  add constraint casso_cidb_fk
    foreign key (cidb)
    references characters(id)
  on delete cascade;

# --- !Downs

drop table if exists users                cascade;
drop table if exists characters           cascade;
drop table if exists games                cascade;
drop table if exists notes                cascade;
drop table if exists gameAssociation      cascade;
drop table if exists characterAssociation cascade;

drop sequence if exists        user_seq;
drop sequence if exists        game_seq;
drop sequence if exists      public_seq;
drop sequence if exists association_seq;


