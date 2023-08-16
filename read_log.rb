require 'optparse'
require 'json'

options = {}
opt_parser = OptionParser.new do |opts|
  opts.banner = "Usage: ruby read_log.rb [options]"

  opts.on("-k", "--kills", "Prints kills report for each match") do |n|
    options[:kills] = n
  end

  opts.on("-m", "--means", "Prints death means report for each match") do |n|
    options[:means] = n
  end

  opts.on("-f", "--file=FILE", "Specify the file path for input log file. Defaults to qgames.log") do |n|
    options[:file] = n
  end

  opts.on("-h", "--help", "Prints this help") do
    puts opts
    exit
  end
end.parse!

def read_log(options = {})
    path = options[:file] || 'qgames.log'
    if !File.exists? path 
        puts 'The specified file does not exist.'
        exit
    end

    content = File.open(path).readlines.map(&:chomp)

    match_num = 0

    matches = {}
    means = {}

    content.each do |line|
        if line[7..14] == 'InitGame'
            match_num += 1
            matches["game_#{match_num}"] = { 'total_kills' => 0, 'players' => [], 'kills' => {} }
            means["game_#{match_num}"] = { 'kills_by_means' => {} }
        elsif line[7..10] == 'Kill'
            partial = line.split(':').last
            kill = partial[0..partial.index('killed') - 1].strip
            dead = partial[partial.index('killed') + 6..partial.index(' by ')].strip
            kind = partial[partial.index(' by ') + 4..-1].strip

            if kill == '<world>'
                if matches["game_#{match_num}"]['kills'][dead].nil?
                    matches["game_#{match_num}"]['kills'][dead] = 0
                end    
                matches["game_#{match_num}"]['kills'][dead] -= 1
                #matches["game_#{match_num}"]['kills'][dead] = 0 if matches["game_#{match_num}"]['kills'][dead] < 0 uncomment in case negative score is not allowed
            else
                matches["game_#{match_num}"]['players'] << kill if !matches["game_#{match_num}"]['players'].include? kill
                if matches["game_#{match_num}"]['kills'][kill].nil?
                    matches["game_#{match_num}"]['kills'][kill] = 0
                end
                value = kill == dead ? -1 : 1 #Checking if a player killed themselves, in this case, I am assuming it should decrease 1 point as if world killed
                matches["game_#{match_num}"]['kills'][kill] += value
            end

            matches["game_#{match_num}"]['players'] << dead if !matches["game_#{match_num}"]['players'].include? dead
            matches["game_#{match_num}"]['total_kills'] += 1

            if means["game_#{match_num}"]['kills_by_means'][kind].nil?
                means["game_#{match_num}"]['kills_by_means'][kind] = 0
            end
            means["game_#{match_num}"]['kills_by_means'][kind] += 1
        end
    end

    output_path = 'output/'

    Dir.mkdir(output_path) if !Dir.exists? output_path

    File.write("#{output_path}kills.json", JSON.dump(matches))
    puts "File #{output_path}kills.json saved"

    File.write("#{output_path}means.json", JSON.dump(means))
    puts "File #{output_path}means.json saved"
end

def run_report(options = {}, file_name)
    file_path = "output/#{file_name}.json"
    if !File.exists? file_path
        read_log(options)
    end
    puts "--------#{file_name.upcase} REPORT--------"
    content = File.read(file_path)
    puts content

    if file_name == 'kills' # Player Ranking
        data = JSON.parse(content)

        ranking = {}
        player_data = data.map { |k, v| v['kills'] }
        player_data.each do |data|
            data.keys.each do |k|
                if ranking[k].nil?
                    ranking[k] = data[k]
                else
                    ranking[k] += data[k]
                end
            end
        end
        puts "--------PLAYER RANKING--------"
        puts ranking.sort_by{ |k, v| -v }.to_h
    end
end

if options[:kills]
    run_report options, 'kills'
end

if options[:means]
    run_report options, 'means'
end