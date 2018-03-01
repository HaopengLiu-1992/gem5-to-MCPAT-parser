require 'nokogiri'
require 'inifile'

@xml = File.open("template.xml") { |f| Nokogiri::XML(f) }
@stat = File.open("stats.txt")

@element_hash = Hash.new

@config = IniFile.load('config.ini')

def xml_parser
  hash_config = Hash.new
  hash_stat = Hash.new
  load('param',hash_config)
  load('stat',hash_stat)
  [hash_config, hash_stat]
end

def load(name,hash)
  @xml.css(name).each do |d|
    d.each do |attr_name, attr_value|
      if attr_value.to_s.start_with? "REPLACE"
        attr_value.slice! 'REPLACE{'
        attr_value.slice! '}'
        hash[attr_value] = nil

        if attr_value.include? ','
          attr_value.split(',').each do |v|
            if v.include? 'config'
              hash[v] = nil
            end
          end
        end

        if(attr_value.include? "+")
          attr_value.split('+').each do |v|
            if (v.include? 'config') or (v.include? 'stats')
              v.strip!
              hash[v] = nil
            end
          end
        end

        if(attr_value.include? "-")
          attr_value.split('-').each do |v|
            if (v.include? 'config') or (v.include? 'stats')
              v.strip!
              hash[v] = nil
            end
          end
        end

        if attr_value == 'int(stats.system.cpu.rename.RenamedOperands * stats.system.cpu.rename.int_rename_lookups / stats.system.cpu.rename.RenameLookups)'
          hash['stats.system.cpu.rename.RenamedOperands'] = nil
          hash['stats.system.cpu.rename.fp_rename_lookups'] = nil
          hash['stats.system.cpu.rename.RenameLookups'] = nil
        end

        if attr_value == 'stats.system.l2.demand_accesses::total * 2'
          hash['stats.system.l2.demand_accesses::total'] = nil
        end

      end
    end
  end
end

def simple_load()
  @xml.css('param').each do |d|
    d.each do |name, value|
      if value.to_s.start_with? "REPLACE"
        value.slice! 'REPLACE{'
        value.slice! '}'
        @element_hash[value] = nil
      end
    end
  end

  @xml.css('stat').each do |d|
    d.each do |name, value|
      if value.to_s.start_with? "REPLACE"
        value.slice! 'REPLACE{'
        value.slice! '}'
        @element_hash[value] = nil
      end
    end
  end
end

def stats_parser
  hash = Hash.new
  @stat.each do |line|
    element = line.split('#')[0].split(' ')
    if element.length == 2 || element.length == 4
      hash[element[0]] = element[1] if hash[element[0]].nil?
    end
  end
  hash
end

def config_parser
  hash = Hash.new
  @config.each do |config|
    @config[config].each do |key, value|
      hash_key = config+'.'+key
      hash_value = value
      hash[hash_key] = hash_value
    end
  end
  hash
end

def config_value_fill
  config = config_parser
  hash_config = xml_parser[0]

  hash_config.each do |key,value|
    new_key = key.gsub("config.","")
    hash_config[key] = config[new_key]
  end

  hash_config['config.system.cpu.icache.size,config.system.cpu.icache.tags.block_size,config.system.cpu.icache.assoc,1,1,config.system.cpu.icache.data_latency,config.system.cpu.icache.tags.block_size,0'] =
  "#{config['system.cpu.icache.size']},#{config['system.cpu.icache.tags.block_size']},#{config['system.cpu.icache.assoc']},1,1,#{config['system.cpu.icache.data_latency']},#{config['system.cpu.icache.tags.block_size']},0"

  hash_config['config.system.cpu.icache.mshrs,config.system.cpu.icache.mshrs,config.system.cpu.icache.mshrs,config.system.cpu.icache.mshrs'] =
      "#{config['system.cpu.icache.mshrs']},#{config['system.cpu.icache.mshrs']},#{config['system.cpu.icache.mshrs']},#{config['system.cpu.icache.mshrs']}"

  hash_config['config.system.cpu.dcache.size,config.system.cpu.dcache.tags.block_size,config.system.cpu.dcache.assoc,1,1,config.system.cpu.dcache.data_latency,config.system.cpu.dcache.tags.block_size,0'] =
      "#{config['system.cpu.dcache.size']},#{config['system.cpu.dcache.tags.block_size']},#{config['system.cpu.dcache.assoc']},1,1,#{config['system.cpu.dcache.data_latency']},#{config['system.cpu.dcache.tags.block_size']},0"

  hash_config['config.system.cpu.dcache.mshrs,config.system.cpu.dcache.mshrs,config.system.cpu.dcache.mshrs,config.system.cpu.dcache.mshrs'] =
      "#{config['system.cpu.dcache.mshrs']},#{config['system.cpu.dcache.mshrs']},#{config['system.cpu.dcache.mshrs']},#{config['system.cpu.dcache.mshrs']}"

  hash_config['config.system.l2.size,config.system.l2.tags.block_size,config.system.l2.assoc,1,1,config.system.l2.data_latency,config.system.l2.tags.block_size,1'] =
      "#{config['system.l2.size']},#{config['system.l2.tags.block_size']},#{config['system.l2.assoc']},1,1,#{config['system.l2.data_latency']},#{config['system.l2.tags.block_size']},1"

  hash_config['config.system.l2.mshrs,config.system.l2.mshrs,config.system.l2.mshrs,config.system.l2.mshrs'] =
      "#{config['system.l2.mshrs']},#{config['system.l2.mshrs']},#{config['system.l2.mshrs']},#{config['system.l2.mshrs']}"

  hash_config['1e-6/( config.system.clk_domain.clock * 1e-12)'] = (1000000/config['system.clk_domain.clock']).to_s

  hash_config
end

def stats_value_fill
  hash_stats = xml_parser[1]
  stats = stats_parser
  hash_stats.each do |key, value|
    new_key = key.gsub('stats.','')
    hash_stats[key] = stats[new_key]
  end

  hash_stats.each do |key, value|
    new_key = key.gsub('stats.','')
    hash_stats[key] = stats[new_key]
    if(key.include? "+")
      sum = 0
      key.split('+').each do |v|
        v.strip!
        new_key = v.gsub('stats.','')
        sum = sum + stats[new_key].to_i
      end
      hash_stats[key] = sum.to_s
    end
  end

  hash_stats['stats.system.l2.demand_accesses::total * 2'] = (stats['system.l2.demand_accesses::total'].to_i*2).to_s

  hash_stats['stats.system.cpu.numCycles - stats.system.cpu.idleCycles'] = (stats['system.cpu.numCycles'].to_i - stats['system.cpu.idleCycles'].to_i).to_s

  hash_stats['int(stats.system.cpu.rename.RenamedOperands * stats.system.cpu.rename.int_rename_lookups / stats.system.cpu.rename.RenameLookups)'] =
      (stats['system.cpu.rename.RenamedOperands'].to_i * stats['system.cpu.rename.int_rename_lookups'].to_i/stats['system.cpu.rename.RenameLookups'].to_i).to_i.to_s

  hash_stats['int(stats.system.cpu.rename.RenamedOperands * stats.system.cpu.rename.fp_rename_lookups / stats.system.cpu.rename.RenameLookups)'] =
      (stats['system.cpu.rename.RenamedOperands'].to_i * stats['system.cpu.rename.fp_rename_lookups'].to_i/stats['system.cpu.rename.RenameLookups'].to_i).to_i.to_s

  hash_stats
end

def parser
  config = config_value_fill
  stats = stats_value_fill
  simple_load
  puts @element_hash.size
  @element_hash.each do |key,value|
    @element_hash[key] = config[key] unless config[key].nil?
    @element_hash[key] = stats[key] unless stats[key].nil?
  end
end

def export_xml
  parser
  f = File.open('template.xml','r')
  File.new('output.xml','w')
  f.each_line do |line|
    if line.include? "REPLACE{"
      s = line.index("{")
      e = line.index("}")
      key = line[s+1,e-s-1]
      previous = "REPLACE{"+key+"}"
      value = @element_hash[key].to_s
      if value.length == 0
        value = @element_hash['stats.system.cpu.iq.FU_type_0::No_OpClass + stats.system.cpu.iq.FU_type_0::IntAlu + stats.system.cpu.iq.FU_type_0::IntMult + stats.system.cpu.iq.FU_type_0::IntDiv + stats.system.cpu.iq.FU_type_0::IprAccess']
      end
      line.gsub!(previous,value)
    end
    puts line
    File.open('output.xml', 'a') { |f| f.write(line) }
  end
end


export_xml
