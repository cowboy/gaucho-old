require 'grit'
require 'pp'
require 'fileutils'

@repo_path = File.expand_path('test_repo')
FileUtils.rm_rf(@repo_path)
FileUtils.mkdir_p(@repo_path)
FileUtils.cd(@repo_path)
`git init .`

@articles = ['gallimaufry', 'haptic', 'lacuna', 'sidereal', 'risible', 'turophile', 'Scotch woodcock', 'scion', 'opprobrium', 'paean', 'brobdignagian', 'abecedarian', 'paronomasia', 'woodnote', 'second banana', 'ben trovato', 'putative', 'algid', 'piste', 'synchronicity', 'factotum', 'festschrift', 'jato unit', 'materteral', 'skepsis', 'micawber', 'jitney', 'retral', 'sobriquet', 'tumid', 'pule', 'meed', 'oscitate', 'oolert', 'sartorial', 'vitiate', 'chiliad', 'aestival', 'sylva', 'stat', 'anomie', 'cheval-de-frise', 'pea-souper', 'autochthon', 'jument', 'lascivious', 'aglet', 'bildungsroman', 'comity', 'devil theory', 'embrocation', 'fug', 'gat', 'hidrosis', 'irenic', 'jeremiad', 'kerf', 'legerity', 'marmoreal', 'naff', 'oikology', 'pessimal', 'quidam', 'recondite', 'sybaritic', 'tyro', 'ullage', 'vigorish', 'writhen', 'xanthochroi', 'yestreen', 'zenana', 'gribble', 'pelf', 'aeneous', 'forb', 'eleemosynary', 'foofaraw', 'lanai', 'shandrydan', 'tardigrade', 'ontic', 'lubricious', 'inchmeal', 'costermonger', 'pilgarlic', 'costard', 'quotidian', 'nystagmus', 'bathos', 'dubiety', 'jactation', 'lubritorium', 'cullion', 'wallydrag', 'literatim', 'flaneur', 'cuesta', 'anodyne', 'weazen', 'brumal', 'estaminet', 'incarnadine', 'gork', 'xanthous', 'yoni', 'demersal', 'anthemion', 'clapperclaw', 'kloof', 'pavid', 'wyvern', 'flannelmouthed', 'chondrule', 'petitio principii', 'kyte', 'pawky', 'katzenjammer', 'catchpenny', 'quincunx', 'Rabelaisian', 'cogent', 'abulia', 'roundheel', 'bruxism', 'kempt', 'aeolian', 'chorine', 'infrangible', 'patzer', 'mistigris', 'misoneism', 'discalceate', 'mimesis', 'pleonasm', 'bezoar', 'volacious', 'demiurgic', 'kakistocracy', 'mell', 'psilanthropy', 'pulchritude', 'embrangle', 'exigent', 'clapter', 'Esperanto', 'wamble', 'maven', 'pulvinar', 'digerati', 'exiguous', 'prolegomenon', 'wapper jaw', 'pridian', 'dirl', 'viviparous', 'brickbat', 'colporteur', 'ditty bag', 'denouement', 'miscegenation', 'vavasor', 'xerosis', 'gunda', 'looby', 'nabob', 'planogram', 'zarf', 'xyloid', 'invidious', 'nugatory', 'decrescent', 'palmy', 'frittle', 'risorial', 'agnail', 'demesne', 'asperse', 'crankle', 'dulcorate', 'chirm', 'blague', 'humbug', 'diapason', 'nares', 'palliate', 'narghile', 'flagitious', 'fizgig', 'troilism', 'bandicoot', 'acid test', 'achilous', 'irpe', 'irredenta', 'balter', 'tripsis', 'gormless', 'anfractuous', 'lulliloo']
@articles = @articles[0..20] #make things smaller and faster

@all_cats = %w(news projects articles music photography)
@all_tags = %w(fun awesome cool lame bad sweet great money weak zesty)

@all_texts = [
  '## Sample Header',
  '### Sample Sub-Header',
  '{{toc}}',
  %Q{This text has **bold** and _italic_ text, some "quoted text that can't be beat," and look, [an external link](http://benalman.com) too!},
  'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Curabitur at erat id tellus rutrum cursus. Cras et elit est. Duis a eleifend metus. Proin ultrices hendrerit rutrum. Fusce id sapien nec dolor elementum tempus nec pulvinar diam. Sed euismod, sem ut luctus ullamcorper, nibh tellus volutpat felis, eget tempor quam sem a tortor. Nam tortor felis, mollis vitae vehicula non, consequat vel magna.',
  'Mauris suscipit cursus fringilla. Donec ut nisl quam, non blandit odio. Aenean quis est a massa iaculis ultricies. Nulla vel velit magna. Vivamus eget tortor ipsum, ac feugiat augue. Vivamus vel ipsum lorem. Praesent sapien massa, egestas venenatis tempor et, auctor ac libero. Curabitur id lorem eget nisi faucibus placerat. Vestibulum vitae nisl erat, quis elementum enim. Proin ac felis pellentesque ante malesuada pellentesque tempus sit amet tortor.',
  "* List item 1\n* List item 2\n* List item 3",
  "1. Ordered list item 1\n2. Ordered list item 2\n3. Ordered list item 3",
]

@all_incls = []
@all_incls << ['sample.rb', <<EOF
def wtf(x)
  if x < 17 && x > 5
    puts "yay, the < and > were escaped properly"
  end
end
EOF
]
@all_incls << ['awesome.js', <<EOF
function awesome() {
  console.log( 'OMG AWESOME!1' );
}
EOF
]
@all_incls << ['fancy.css', <<EOF
body.fancy {
  color: red;
  background: blue;
}
EOF
]
@all_incls << ['lol.html', <<EOF
<h1>LOL!!</h1>
EOF
]
@all_incls << ['lolwat.html', <<EOF
<h1>LOL WAT</h1>
<h2>SUPER DUPER COOL</h2>
EOF
]
@all_incls << ['haiku.txt', <<EOF
this is a sample
text file with the answer to
the meaning of life
EOF
]
@all_incls << ['single.txt', <<EOF
this is a single line text file
EOF
]
@all_incls << ['escaped_html.txt', <<EOF
<h2>ZOMG ESCAPED HTML</h2>
EOF
]

@page_subdirs = ['yay/', 'nay/']
@file_subdirs = ['', 'foo/', 'bar/', 'foo/bar/']

@paths = {}

def content_name_path(a)
  unless @paths[a]
    name = "#{a} is a cool word"
    subdir = @page_subdirs.shuffle.first
    date = if rand(10) > 5
      [
        2008 + rand(2),
        "%02d" % (1 + rand(12)),
        "%02d" % (1 + rand(28))
      ].join('-') + '-'
    else
      ''
    end
    @paths[a] = [
      name,
      "#{@repo_path}/#{subdir}#{date}#{name.downcase.gsub(/\s+/, '-')}"
    ]
  end
  @paths[a]
end

def create_article(a)
  name, path = content_name_path(a)
  cats = @all_cats.shuffle[0..rand(1)].join(', ')
  tags = @all_tags.shuffle[0..rand(4)].join(', ')
  index = <<EOF
title: #{name}
subtitle: This article is all about the word #{a}.
categories: [ #{cats} ]
tags: [ #{tags} ]
--- |

#{@all_texts.shuffle[0]}

<!--more-->
EOF

  FileUtils.mkdir_p(path)
  File.open("#{path}/index.md", 'w') {|f| f.write(index)}
end

def add_stuff(a)
  name, path = content_name_path(a)
  incl = @all_incls.shuffle[0..1]
  incl.each do |i|
    file_subdir = @file_subdirs.shuffle.first
    index = <<EOF

{{ #{file_subdir}#{i[0]} }}

#{@all_texts.shuffle[0]}
EOF
    File.open("#{path}/index.md", 'a') {|f| f.write(index)}
  
    FileUtils.mkdir_p("#{path}/#{file_subdir}")
    File.open("#{path}/#{file_subdir}#{i[0]}", 'w') {|f| f.write(i[1])}
  end
end

@num_commits = 0

def print_status
  @num_commits += 1
  print '.' if @num_commits % 10 == 1
end

def commit_article(a, added = false)
  sleep 0.1
  `git add .`
  `git commit -m "#{added ? 'Added' : 'Updated'} '#{a}' article."`
  print_status
end

def commit_articles(a, b)
  sleep 0.1
  `git add .`
  `git commit -m "Updated '#{a}' and '#{b}' articles."`
  print_status
end

@articles.each {|a| a[0] = a[0].upcase}

print 'Working'

@articles.each do |a|
  create_article(a)
  add_stuff(a)
  commit_article(a, true)
end

if true
  @articles.each_index do |i|
    next if i % 2 == 1
    a = @articles[i]
    b = @articles[i + 1]
    add_stuff(a)
    if b
      add_stuff(b)
      commit_articles(a, b)
    else
      commit_article(a)
    end
  end

  @articles.each do |a|
    add_stuff(a)
    commit_article(a)
    add_stuff(a)
    commit_article(a)
    add_stuff(a)
    commit_article(a)
  end

  @articles.each do |a|
    add_stuff(a)
    commit_article(a)
    add_stuff(a)
    commit_article(a)
  end

  @articles.each do |a|
    add_stuff(a)
    commit_article(a)
    add_stuff(a)
    commit_article(a)
    add_stuff(a)
    commit_article(a)
  end
end

puts 'done!'
