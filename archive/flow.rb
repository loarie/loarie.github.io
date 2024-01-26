def do_it taxa
  taxa.children.each do |taxon|
    puts taxon.name
    if taxon.observations_count > 10000
      observations_count = Observation.joins(:taxon).where("quality_grade IN (?) AND (taxon_id = ? OR taxa.ancestry LIKE ? OR taxa.ancestry LIKE ?)", ["needs_id", "research"], taxon.id, "%/#{taxon.id}/%", "%/#{taxon.id}").count
      if observations_count > 10000
        puts "go smaller"
        do_it taxon
      else
        puts "stop"
        LEAVES << taxon.parent.id
      end
    else
      puts "stop"
      LEAVES << taxon.parent.id
    end
  end
end

LEAVES = []
t = Taxon.find_by_id(48460)
do_it t

leaves = LEAVES.uniq
taxa = Taxon.where("id IN (?)", leaves)
ancestors = taxa.map{|a| a.ancestry}.join("/").split("/").map{|a| a.to_i}.uniq
final = (leaves - ancestors)
Taxon.where("id IN (?)", final).map{|a| puts a.name}

Taxon.where("id IN (?)", leaves).map{|a| puts "#{a.name},#{a.observations_count}"}

Taxon.where("id IN (?)", leaves).sort_by{|a| a.observations_count}.map{|a| puts "#{a.name},#{a.observations_count}"}

Odonata,44778
Fungi,59037
Asteraceae,64790
Asterales,68071
Squamata,71086
Papilionoidea,72598
Mammalia,80471
Liliopsida,84124
Reptilia,86501
Lepidoptera,185344
Passeriformes,186225
Pterygota,373011
Insecta,379891
Hexapoda,380339
Arthropoda,431818

Animalia
Chordata
Vertebrata
Aves
Plantae
Tracheophyta
Magnoliophyta
Magnoliopsida


t = Taxon.where("id IN (?)", final)
taxa = t.map(&:id)
taxon_ancestors = t.map(&:ancestry)
taxon_ancestries = taxon_ancestors.zip(taxa).map{|i| i.join("/")}

taxon_key = Hash[t.map(&:id).zip(t.map(&:name))] 

class Hash
  def nav_tree(ind)
    fetch("children")[ind]
  end
end

taxon_tree = {"id" => 48460, "name" => "Life", "children" => []}
taxon_ancestries.each do |ancestry|
  next if ancestry == tid
  key = []
  aids = ancestry.split("/").map{|i| i.to_i}
  (1..(aids.length-1)).each do |ind|
    children = key.inject(taxon_tree, :nav_tree)["children"]
    slot = children.count
    if slot == 0 #add it
      key.inject(taxon_tree, :nav_tree)["children"][slot] = {"id" => aids[ind], "name" => taxon_key[aids[ind]], "children" => []}
      key << slot
    else
      match = false
      (0..slot-1).each do |s|
        next if match
        if key.inject(taxon_tree, :nav_tree)["children"][s]["id"] == aids[ind] #use this and proceed
          key << s
          match = true
        end
      end
      unless match
        key.inject(taxon_tree, :nav_tree)["children"][slot] = {"id" => aids[ind], "name" => taxon_key[aids[ind]], "children" => []}
        key << slot
      end
    end
  end
end

puts taxon_tree.to_json


taxon = Taxon.find_by_id(1)
Observation.joins(:taxon).where("taxon_id = ? OR taxa.ancestry LIKE ? OR taxa.ancestry LIKE ?", taxon.id, "%/#{taxon.id}/%", "%/#{taxon.id}").count

Life

{"nodes":[
{"name":"Agricultural 'waste'"},
{"name":"Bio-conversion"}
],
"links":[
{"source":0,"target":1,"value":124.729},
{"source":1,"target":2,"value":0.597}
]}


def one_lev(taxon, source)
  taxon.children.where(is_active: true).each do |t|
    obs_count = t.observations_count
    unless obs_count == 0
      puts "working on #{t.name} (#{obs_count})"
      $count = $count + 1
      NODES << {"name" => t.name, "id" => t.id, "obs_count" => obs_count}
      LINKS << {"source" => source, "target" => $count, "value" => obs_count}
      if NAMES.include? t.name
        puts "continuing"
        one_lev(t, $count)
      else
        puts "stopping"
      end
    end
  end
end

#NAMES = ["Magnoliopsida","Chelicerata","Chordata","Plantae","Animalia","Arthropoda","Vertebrata","Tracheophyta","Hexapoda", "Insecta", "Pterygota","Magnoliophyta", "Aves"]
NAMES = ["Chelicerata","Chordata","Animalia","Arthropoda","Vertebrata","Hexapoda"]
NODES = []
LINKS = []
$count = 0
taxon = Taxon.find_by_id(48460)
source = $count
NODES << {"name" => taxon.name, "id" => 48460, "obs_count" => taxon.observations_count}
one_lev(taxon, source)

ids = NODES.map{|a| a["id"]}
taxa = Taxon.where("id IN (?)", ids)
ancestors = taxa.map{|a| a.ancestry}.join("/").split("/").map{|a| a.to_i}.uniq
final = (ids - ancestors)
leaf_names = Taxon.where("id IN (?)", final).map{|a| a.name}
NODES.select{|a| leaf_names.include? a["name"]}.map{|a| a["obs_count"]}.sum
iconics = ["Mammalia", "Fungi", "Insecta", "Plantae", "Aves", "Arachnida", "Actinopterygii", "Reptilia", "Mollusca", "Amphibia"]
NODES.select{|a| iconics.include? a["name"]}.map{|a| a["obs_count"]}.sum
1810318/1851024.to_f #97.8

NODES.select{|a| leaf_names.include? a["name"]}.select{|a| !iconics.include? a["name"]}.sort_by{|a| -a["obs_count"]}.map{|a| puts "#{a["name"]}, #{a["obs_count"]}"}

Other (10):
Crustacea, 12058
Echinodermata, 5743
Cnidaria, 5167
Myriapoda, 4226
Chromista, 3608
Annelida, 2368
Protozoa, 1793
Chondrichthyes, 1531
Tunicata, 824
Platyhelminthes, 742
#0.95%

Insects (10):
Lepidoptera, 185360
Odonata, 44789
Coleoptera, 35966
Hymenoptera, 33879
Hemiptera, 23229
Diptera, 21825
Orthoptera, 14488
Mantodea, 2961
Neuroptera, 1819
Ephemeroptera, 1650
#0.98%

Birds (20):
Passeriformes, 186272
Anseriformes, 43973
Charadriiformes, 41488
Pelecaniformes, 27785
Accipitriformes, 27297
Columbiformes, 23825
Piciformes, 14345
Gruiformes, 11841
Apodiformes, 8995
Suliformes, 7845
Psittaciformes, 7138
Galliformes, 6924
Falconiformes, 6202
Coraciiformes, 4999
Strigiformes, 4915
Podicipediformes, 4463
Cuculiformes, 2868
Procellariiformes, 1915
Gaviiformes, 1252
Ciconiiformes, 1105

Plants (20):
Asteraceae, 64807
Fabaceae, 30009
Pteridophyta, 22995
Pinophyta, 22515
Rosaceae, 22128
Poaceae, 17556
Fagaceae, 12347
Lamiaceae, 11314
Cactaceae, 10984
Ericaceae, 10528
Asparagaceae, 9630
Plantaginaceae, 9266
Brassicaceae, 8931
Orchidaceae, 8870
Sapindaceae, 8764
Boraginaceae, 8413
Apiaceae, 8327
Polygonaceae, 8299
Apocynaceae, 7755
Bryophyta, 7454

Fungi (10):
Agaricales, 16004
Lecanoromycetes, 10518
Polyporales, 5027
Boletales, 2554
Russulales, 2355
Pezizomycetes, 1294
Sordariomycetes, 933
Cantharellales, 727
Leotiomycetes, 711
Auriculariales, 546
#91%

Mollusks (4):
Gastropoda,25180
Bivalvia,4108
Polyplacophora,1333
Cephalopoda,784
#99.9%

Arachnids (5):
Araneae, 27917
Opiliones, 1560
Acari, 1451
Scorpiones, 1361
Solifugae, 224

Amphibians (5):
Ranidae, 9294
Hylidae, 9136
Bufonidae, 7565
Plethodontidae, 5456
Salamandridae, 3665

Reptiles (10):
Colubridae, 21172
Phrynosomatidae, 14210
Emydidae, 7354
Viperidae, 7008
Gekkota, 4206
Dactyloidae, 3620
Scincidae, 3589
Teiidae, 2483
Anguidae, 2258
Lacertidae, 2187

Mammals (10):
Carnivora, 21708
Rodentia, 20116
Artiodactyla, 15113
Lagomorpha, 5500
Chiroptera, 4974
Primates, 2947
Cetacea, 2171
Diprotodontia, 1316
Didelphimorphia, 1262
Perissodactyla, 1072
#96%

Fishes (20):
Labridae, 2618
Syngnathiformes, 2355
Pomacentridae, 2133
Tetraodontiformes, 1935
Cypriniformes, 1774
Chaetodontidae, 1642
Centrarchidae, 1600
Scorpaeniformes, 1515
Salmoniformes, 1376
Gobiidae, 1184
Serranidae, 1172
Osmeriformes, 1155
Acanthuridae, 1098
Cyprinodontiformes, 986
Anguilliformes, 984
Scaridae, 776
Pomacanthidae, 644
Siluriformes, 628
Lutjanidae, 540
Cichlidae, 526
#74%

NAMES = ["Bivalvia"]
NODES = []
LINKS = []
$count = 0
taxon = Taxon.find_by_id(3)
source = $count
NODES << {"name" => taxon.name, "id" => 3, "obs_count" => taxon.observations_count}
one_lev(taxon, source)
NODES.sort_by{|a| -a["obs_count"]}[0..50].map{|a| puts "#{a["name"]}, #{a["obs_count"]}"}

NODES.sort_by{|a| -a["obs_count"]}[2..13].map{|a| puts "#{a["name"]}, #{a["obs_count"]}"}
NODES.sort_by{|a| -a["obs_count"]}[5..13].map{|a| a["obs_count"]}.sum+16004
NODES.sort_by{|a| -a["obs_count"]}[5..100].map{|a| a["obs_count"]}.sum+16004
76179/159521.to_f

