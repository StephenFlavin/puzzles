create table words_staging (word text primary key);
copy words_staging(word) FROM '/usr/share/dict/words';

create table words (word text primary key);
insert into words (word) select distinct lower(word) from words_staging; -- removes duplicates from the dictionary
drop table words_staging;

create table letters_staging(key varchar(1) primary key, value varchar(1)[]);
insert into letters_staging (key, value) values
  ('b', ARRAY['y','t','l','r','o']),
  ('r', ARRAY['b','l','e','c','o']),
  ('c', ARRAY['r','e','g','h','o']),
  ('h', ARRAY['c','g','w','s','o']),
  ('s', ARRAY['h','w','n','y','o']),
  ('y', ARRAY['b','t','n','s','o']),
  ('l', ARRAY['b','r','e','t','o']),
  ('e', ARRAY['r','c','g','o','l']),
  ('g', ARRAY['e','c','h','w','o']),
  ('w', ARRAY['o','g','h','s','n']),
  ('n', ARRAY['t','o','w','s','y']),
  ('t', ARRAY['b','l','o','n','y']),
  ('o', ARRAY['b','r','c','h','s','y','l','e','g','w','n','t']);

create table letters (key varchar(1), value varchar(1), primary key (key, value));
insert into letters (key, value) select key, unnest(value) from letters_staging; -- every letter in the graph now has one row per linked letter
drop table letters_staging;

with recursive a(key, value, concat, possible_words) as (
      select key,
             value,
             concat(key, value),
             array_agg(words.word) -- builds an array of possible words for a given pair of letters
      from letters
      join words on left(words.word, 2) = concat(letters.key, letters.value)
        and length(words.word) > 2 -- skipping the 1 and 2 letter words in the loop shaves 8 seconds off the execution time
      group by letters.key, letters.value
    union all
      select b.key,
             b.value,
             concat(a.concat, b.value), -- this accumulates the joining letters together
             (select array_agg(unnested_val)
              from (select unnest(possible_words) unnested_val) _
              where left(unnested_val, length(concat(a.concat, b.value))) = concat(a.concat, b.value)) -- remove now impossible matches from the array of possible words
      from letters b
      join a on a.value = b.key
      where array_length(possible_words, 1) > 0 -- stop looping when there is only one possible word
)
select concat
from a
where concat = any(possible_words) -- filter output to word matches
union all
select distinct words.word -- grab the 1 and 2 letter words
from words
join letters on letters.key = words.word
  or concat(letters.key, letters.value) = words.word;