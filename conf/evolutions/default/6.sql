# --- Sixth database schema

# --- !Ups

alter table users
  add column openid boolean not null default false;

# --- !Downs

alter table users
  drop column if exists openid;

