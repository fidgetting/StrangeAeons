# --- Second database schema

# --- !Ups

create sequence asepct_seq start with 1;

create table aspects (
  id  bigint
      constraint pk_aspect
      primary key
      default nextval('asepct_seq'::regclass),
  
  user_id  bigint       not null,
  name     varchar(255) not null,
  data     text
);

alter table aspects
  add constraint aspect_user_fk
    foreign key (user_id)
    references users(id)
  on delete cascade;

# --- !Downs

drop table if exists aspects cascade;
drop sequence if exists asepct_seq;
