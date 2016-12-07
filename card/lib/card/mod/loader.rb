# -*- encoding : utf-8 -*-

require_dependency "card/set"
require_dependency "card/set_pattern"

class Card
  class << self
    def config
      Cardio.config
    end

    def paths
      Cardio.paths
    end
  end

  module Mod
    module Loader
      class << self
        def load_mods
          load_set_patterns
          load_formats
          load_sets
        end

        def load_chunks
          mod_dirs.each(:chunk) do |dir|
            load_dir dir
          end
        end

        def load_layouts
          hash = {}
          mod_dirs.each(:layout) do |dirname|
            Dir.foreach(dirname) do |filename|
              next if filename =~ /^\./
              layout_name = filename.gsub(/\.html$/, "")
              hash[layout_name] = File.read File.join(dirname, filename)
            end
          end
          hash
        end

        def mod_dirs
          @mod_dirs ||= Mod::Dirs.new(Card.paths["mod"].existent)
        end

        def refresh_script_and_style
          update_if_source_file_changed Card[:all, :script]
          update_if_source_file_changed Card[:all, :style]
        end

        private

        # regenerates the machine output if a source file of a input card
        # has been changed
        def update_if_source_file_changed machine_card
          return unless machine_card
          mtime_output = machine_card.machine_output_card.updated_at
          return unless mtime_output
          regenerate = false
          input_cards_with_source_files(machine_card) do |i_card, files|
            files.each do |path|
              next unless File.mtime(path) > mtime_output
              i_card.expire_machine_cache
              regenerate = true
              break
            end
          end
          return unless regenerate
          machine_card.regenerate_machine_output
        end

        def input_cards_with_source_files card
          card.machine_input_card.extended_item_cards.each do |i_card|
            next unless i_card.codename
            next unless i_card.respond_to?(:existing_source_paths)
            yield i_card, i_card.existing_source_paths
          end
        end

        def source_files card
          files = []
          card.machine_input_card.extended_item_cards.each do |i_card|
            next unless i_card.codename
            next unless i_card.respond_to?(:existing_source_paths)
            files << i_card.existing_source_paths
          end
          files.flatten
        end

        def load_set_patterns
          generate_set_pattern_tmp_files if rewrite_tmp_files?
          load_dir Card.paths["tmp/set_pattern"].first
        end

        def generate_set_pattern_tmp_files
          prepare_tmp_dir "tmp/set_pattern"
          seq = 100
          mod_dirs.each(:set_pattern) do |dirname|
            Dir.entries(dirname).sort.each do |filename|
              m = filename.match(/^(\d+_)?([^\.]*).rb/)
              key = m && m[2]
              next unless key
              filename = [dirname, filename].join("/")
              Set::Pattern.write_tmp_file key, filename, seq
              seq += 1
            end
          end
        end

        def load_formats
          # cheating on load issues now by putting all inherited-from formats in
          # core mod.
          mod_dirs.each(:format) do |dir|
            load_dir dir
          end
        end

        def load_sets
          generate_tmp_set_modules
          load_tmp_set_modules
          Set.process_base_modules
          Set.clean_empty_modules
        end

        def generate_tmp_set_modules
          return unless prepare_tmp_dir "tmp/set"
          mod_dirs.each_with_tmp(:set) do |mod_dir, mod_tmp_dir|
            Dir.mkdir mod_tmp_dir
            Dir.glob("#{mod_dir}/**/*.rb").each do |abs_filename|
              rel_filename = abs_filename.gsub "#{mod_dir}/", ""
              tmp_filename = "#{mod_tmp_dir}/#{rel_filename}"
              Set.write_tmp_file abs_filename, tmp_filename, rel_filename
            end
          end
        end

        def load_tmp_set_modules
          patterns = Card.set_patterns.reverse.map(&:pattern_code)
                         .unshift "abstract"
          mod_dirs.each_tmp(:set) do |set_tmp_dir|
            patterns.each do |pattern|
              pattern_dir = "#{set_tmp_dir}/#{pattern}"
              load_dir "#{pattern_dir}/**" if Dir.exist? pattern_dir
            end
          end
        end

        def prepare_tmp_dir path
          return unless rewrite_tmp_files?
          p = Card.paths[path]
          FileUtils.rm_rf p.first, secure: true if p.existent.first
          Dir.mkdir p.first
        end

        def rewrite_tmp_files?
          if defined?(@rewrite)
            @rewrite
          else
            @rewrite = !(Rails.env.production? &&
                         Card.paths["tmp/set"].existent.first)
          end
        end

        def load_dir dir
          Dir["#{dir}/*.rb"].sort.each do |file|
            # puts Benchmark.measure("from #load_dir: rd: #{file}") {
            require_dependency file
            # }.format('%n: %t %r')
          end
        end
      end
    end
  end
end
