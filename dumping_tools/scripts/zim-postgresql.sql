create table mimetype
(
  id           integer not null primary key,
  mimetype     text not null,
  compress     boolean not null
);

create table article
(
  aid          serial  not null primary key,
  namespace    text    not null,
  url          text    not null,
  title        text    not null,
  redirect     text,     -- title of redirect target
  mimetype     integer,
  data         bytea,
  foreign key (mimetype) references mimetype
);

create unique index article_ix1 on article(namespace, url);

create table category
(
  cid          serial  not null primary key,
  title        text    not null,
  description  bytea   not null
);

create table categoryarticle
(
  cid          integer not null,
  aid          integer not null,
  primary key (cid, aid),
  foreign key (cid) references category,
  foreign key (aid) references article
);

create table zimfile
(
  zid          serial  not null primary key,
  filename     text    not null,
  mainpage     integer,
  layoutpage   integer,
  foreign key (mainpage) references article,
  foreign key (layoutpage) references article
);

create table zimarticle
(
  zid          integer not null,
  aid          integer not null,

  primary key (zid, aid),
  foreign key (zid) references zimfile,
  foreign key (aid) references article
);

create table indexarticle
(
  zid          integer not null,
  xid          serial  not null,
  namespace    text    not null,
  title        text    not null,

  primary key (zid, namespace, title),
  foreign key (zid) references zimfile
);

create index indexarticle_ix1 on indexarticle(zid, xid);

create table words
(
  word     text not null,
  pos      integer not null,
  aid      integer not null,
  weight   integer not null, -- 0: title/header, 1: subheader, 3: paragraph

  primary key (word, aid, pos),
  foreign key (aid) references article
);

create index words_ix1 on words(aid);

create table trivialwords
(
  word     text not null primary key
);
