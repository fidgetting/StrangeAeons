# --- First database schema

# --- !Ups

alter table characterassociation rename column cida to base;
alter table characterassociation rename column cidb to link;

# --- !Downs

alter table characterassociation rename column base to cida;
alter table characterassociation rename column link to cidb;
