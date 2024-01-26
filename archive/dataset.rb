## Get set of obs ids of all verifiable observations in a taxon
taxon_id =  47825 #47208 #64784 #84718 #63561
obs = Observation.select("observations.id, observations.taxon_id, observations.created_at").joins(:taxon).where("(taxon_id = ? OR taxa.ancestry LIKE (?) OR taxa.ancestry LIKE (?)) AND quality_grade IN (?)", taxon_id, "%/#{taxon_id}", "%/#{taxon_id}/%", ["needs_id","research"])
ids = obs.pluck(:id); nil

## dataset & annos

# Get all current identifications of active, rank_level 10 taxa from the set of obs ids
# (Grant is rolling up spp to sp which is not done here)
sql_query = <<-SQL
 SELECT i.id, i.taxon_id, i.user_id, i.observation_id, i.created_at, i.taxon_change_id, i.category
 FROM identifications i, taxa t
 WHERE i.taxon_id = t.id AND i.observation_id IN (#{ids.join(",")})
 AND i.current = TRUE AND t.rank_level = 10 AND t.is_active = TRUE;
SQL
data0 = ActiveRecord::Base.connection.execute(sql_query)

# Keep only identifications where >2 per obs
id_freq = data0.map{|row| row["observation_id"]}.inject(Hash.new(0)) {|hash,word| hash[word] += 1; hash }; nil
keepers = id_freq.select{|k,v| v>1}.keys; nil
data = data0.select{|row| keepers.include? row["observation_id"]}; nil

obs_set0 = data0.map{|row| row["observation_id"].to_i}; nil
obs_set = data.map{|row| row["observation_id"].to_i}; nil

sql_query = <<-SQL
 SELECT * FROM identifications i1
 INNER JOIN 
 (
   SELECT observation_id, user_id, MIN(created_at) AS MINDATE
   FROM identifications
   GROUP BY observation_id, user_id
 ) i2
 ON i1.observation_id = i2.observation_id
 INNER JOIN taxa t
 ON i1.taxon_id = t.id
 AND i1.user_id = i2.user_id
 AND i1.created_at = i2.MINDATE
 WHERE i1.taxon_id = t.id
 AND i1.observation_id IN (#{obs_set.join(",")})
 AND t.rank_level = 10 AND t.is_active = TRUE;
SQL
data2 = ActiveRecord::Base.connection.execute(sql_query)

id_freq = data2.map{|row| row["observation_id"]}.inject(Hash.new(0)) {|hash,word| hash[word] += 1; hash }; nil
keepers = id_freq.select{|k,v| v>1}.keys; nil
data2 = data2.select{|row| keepers.include? row["observation_id"]}; nil

tset = (data2.map{|row| row["taxon_id"]}.to_set | data.map{|row| row["taxon_id"]}.to_set).map{|n| n.to_i}; nil

# Get the taxa by looking at all the observation.taxa
tfreq0 = obs.pluck(:taxon_id).inject(Hash.new(0)) {|hash,word| hash[word] += 1; hash }; nil
#remove any not represented by the IDs
tfreq = tfreq0.select{|k,v| tset.include? k}; nil
#add any represented in the IDs but not in the observation.taxa with a count of 1
tfreq = tfreq.merge(Hash[(tset - tfreq.keys).map{|n| [n,1]}]); nil

taxon_ids = tfreq.keys; nil
inat_taxon_id_to_class_label = Hash[taxon_ids.map.with_index.to_a]; nil 
denom = tfreq.values.inject(0){|sum,x| sum + x }; nil
global_class_priors = tfreq.values.collect { |n| n / denom.to_f }; nil
dataset = {
  inat_taxon_id_to_class_label: inat_taxon_id_to_class_label,
  num_classes: taxon_ids.count,
  global_class_priors: global_class_priors
}; nil

# Store the identifications themselves
annos = data.map{|row|
  {
    anno: {
      gtype: "multiclass",
      label: inat_taxon_id_to_class_label[row["taxon_id"].to_i]
    },
    image_id: row["observation_id"],
    created_at: row["created_at"],
    worker_id: row["user_id"],
    id: row["id"]
  }
}; nil

annos2 = data2.map{|row|
  {
    anno: {
      gtype: "multiclass",
      label: inat_taxon_id_to_class_label[row["taxon_id"].to_i]
    },
    image_id: row["observation_id"],
    created_at: row["created_at"],
    worker_id: row["user_id"],
    id: row["id"]
  }
}; nil

tset = data0.map{|row| row["taxon_id"]}.to_set.map{|n| n.to_i}; nil
#remove any not represented by the IDs
tfreq = tfreq0.select{|k,v| tset.include? k}; nil
#add any represented in the IDs but not in the observation.taxa with a count of 1
tfreq = tfreq.merge(Hash[(tset - tfreq.keys).map{|n| [n,1]}]); nil

taxon_ids = tfreq.keys; nil
inat_taxon_id_to_class_label = Hash[taxon_ids.map.with_index.to_a]; nil 
denom = tfreq.values.inject(0){|sum,x| sum + x }; nil
global_class_priors = tfreq.values.collect { |n| n / denom.to_f }; nil
dataset0 = {
  inat_taxon_id_to_class_label: inat_taxon_id_to_class_label,
  num_classes: taxon_ids.count,
  global_class_priors: global_class_priors
}; nil

annos0 = data0.map{|row|
  {
    anno: {
      gtype: "multiclass",
      label: inat_taxon_id_to_class_label[row["taxon_id"].to_i]
    },
    image_id: row["observation_id"],
    created_at: row["created_at"],
    worker_id: row["user_id"],
    id: row["id"]
  }
}; nil

## workers

# Store the identifiers themselves
user_ids = data.map{|a| a["user_id"]}.uniq; nil
users = user_ids.map{|i| {"id".to_sym => i}}; nil
workers = Hash[users.map{|row| row[:id]}.zip(users)]; nil

user_ids = data2.map{|a| a["user_id"]}.uniq; nil
users = user_ids.map{|i| {"id".to_sym => i}}; nil
workers2 = Hash[users.map{|row| row[:id]}.zip(users)]; nil

user_ids = data0.map{|a| a["user_id"]}.uniq; nil
users = user_ids.map{|i| {"id".to_sym => i}}; nil
workers0 = Hash[users.map{|row| row[:id]}.zip(users)]; nil

## images

# We're not actually using images yet, so fake image urls since getting them is slow
=begin
sql_query = <<-SQL
 SELECT observation_id, photos.medium_url as url FROM observation_photos, photos
 WHERE photos.id = observation_photos.photo_id AND observation_id IN (#{ids.join(",")});
SQL
data4 = ActiveRecord::Base.connection.execute(sql_query)
=end
images = {} 
obs.each do |row|
  next unless obs_set.include? row[:id]
  #matches = data4.select{|row2| row2["observation_id"].to_i == row[:id]}
  images[row[:id]] = {
      url: "https://static.inaturalist.org/photos/6547860/medium.jpg?1489358304", #matches[0]["url"],
      created_at: row[:created_at],
      id: row[:id],
      urls: ["https://static.inaturalist.org/photos/6547860/medium.jpg?1489358304"] #matches.map{|row2| row2["url"]}
    }
end

images0 = {} 
obs.each do |row|
  next unless obs_set0.include? row[:id]
  #matches = data4.select{|row2| row2["observation_id"].to_i == row[:id]}
  images0[row[:id]] = {
      url: "https://static.inaturalist.org/photos/6547860/medium.jpg?1489358304", #matches[0]["url"],
      created_at: row[:created_at],
      id: row[:id],
      urls: ["https://static.inaturalist.org/photos/6547860/medium.jpg?1489358304"] #matches.map{|row2| row2["url"]}
    }
end

## taxonomy_data

# Will use this to get the taxonomy_data
=begin
sql_query = <<-SQL
 SELECT id, rank, rank_level, ancestry, is_active, iconic_taxon_id FROM taxa
 WHERE id IN (#{taxon_ids.join(",")});
SQL
data2 = ActiveRecord::Base.connection.execute(sql_query)
File.open("taxa.json","w") do |f|
  f.write(data2.map{|a| a}.to_json)
end
=end

# Write dataset to file
observation_label_pred_dataset = {images: images, workers: workers, annos: annos, dataset: dataset}; nil
File.open("observation_label_pred_dataset2.json","w") do |f|
  f.write(observation_label_pred_dataset.to_json)
end

worker_skill_pred_dataset = {images: images, workers: workers2, annos: annos2, dataset: dataset}; nil
File.open("worker_skill_pred_dataset2.json","w") do |f|
  f.write(worker_skill_pred_dataset.to_json)
end

test_dataset = {images: images0, workers: workers0, annos: annos0, dataset: dataset0}; nil
File.open("test_dataset2.json","w") do |f|
  f.write(test_dataset.to_json)
end
