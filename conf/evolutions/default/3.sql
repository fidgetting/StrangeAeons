# --- Third database schema

# --- !Ups

create sequence picture_seq start with 1;

# --- !Downs

drop sequence if exists asepct_seq;
