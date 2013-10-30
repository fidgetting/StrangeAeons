# --- Fifth database schema

# --- !Ups

alter table characters
  add column visible boolean not null default true;

update characters
  set public = false;

alter table characters
  alter column public set default false,
  alter column public set not null;

# --- !Downs

alter table characters
  alter column public drop default,
  alter column public drop not null;

update character
  set public = null;

alter table characters
  drop column if exists visible;
