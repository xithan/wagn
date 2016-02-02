class Card
  def self.new_director card, opts={}
    if Card.current_director
      Card.current_director.add_subdirector card
    else
      Card.current_director = StageDirector.new card, opts, false
      Card.current_director.assign_act
      Card.current_director
    end
  end

  def self.register_director director
    Card.directors ||= {}
    Card.directors[director.card.key] = director
  end

  class StageDirector
    def self.stage_index stage
      case stage
      when Symbol then
        return STAGE_INDEX[stage]
      when Integer then
        return stage
      else
        raise Card::Error, "not a valid stage: #{stage}"
      end
    end

    def self.fetch card
      Card.directors ||= {}
      Card.directors[card.key] ||= Card.new_director card
    end

    STAGE_INDEX = {}
    STAGES = [:initialize, :prepare_to_validate, :validate, :prepare_to_store,
              :store, :finalize, :integrate, :integrate_with_delay]
    STAGES.each_with_index do |stage, i|
      STAGE_INDEX[stage] = i
    end

    attr_accessor :subcards, :prior_store, :act, :card

    def initialize card, opts={}, subdirector=false
      @card = card
      @card.director = self
      @card.prepare_for_phases
      @call_after_store = {}
      @stage = nil
      @prior_store = opts[:priority]
      @subdirector = subdirector
      @subdirectors = []
      @subcards = Subcards.new(card)
      register
    end

    def register
      Card.register_director self
    end

    def add_subdirector card
      subdir = StageSubdirector.new(card)
      @subdirectors << subdir
      subdir
    end

    def catch_up_to_stage next_stage
      @stage ||= -1
      (@stage + 1).upto(StageDirector.stage_index(next_stage)) do |i|
        run_single_stage STAGES[i]
      end
    end
    9
    def validation_phase
      run_single_stage :initialize
      run_single_stage :prepare_to_validate
      run_single_stage :validate
      @card.expire_pieces if @card.errors.any?
      @card.errors.empty?
    end

    def storage_phase &block
      run_single_stage :prepare_to_store
      run_single_stage :store, &block
      run_single_stage :finalize
    ensure
      @from_trash = nil
    end

    def integration_phase
      run_single_stage :integrate
      run_single_stage :integrate_with_delay
    ensure
      @card.director = nil
      @subdirectors = nil
      #deep_clear_subcards
      @stage = nil
      @action = nil
    end

    def call_after_store card, &block
      @call_after_store[card.key] ||= []
      @call_after_store[card.key] << block
    end

    def add_to_priority_queue card, subcard
      @store_priority_queue
    end

    def assign_act
      return unless @card.history? || @card.respond_to?(:attachment)
      @act = Card.current_director &&
          (Card.current_director.act || Card::Act.create(ip_address: Env.ip))
      @card.current_act = @act
      @card.assign_action
    end

    def main?
      !@subdirector
    end

    protected


    private

    def rescue_event e
      @card.action = nil
      @card.expire_pieces
      @subcards.each(&:expire_pieces)
      Card.current_director = nil if main?
      raise e
    end

    def store &save_block
      if main? && !block_given?
        fail Card::Error, 'need block to store main card'
      end
      # the block from the around save callback that saves the card
      store_with_subcards &save_block
    end

    def store_with_subcards
      store_prior_subcards
      yield
      if @call_after_store[@card.key]
        @call_after_store[@card.key].each do |handle_id|
          handle_id.call(@card.id)
        end
      end
      store_subcards
      @virtual = false # TODO: find a better place for this
    end

    def store_prior_subcards
      @subdirectors.each do |subdir|
        next unless subdir.prior_store
        subdir.catch_up_to_stage :store
      end
    end

    def store_subcards
      @subdirectors.each do |subdir|
        next if subdir.prior_store
        subdir.catch_up_to_stage :store
      end
    end


    def run_single_stage stage, &block
      #puts "#{name}: #{stage} stage".red
      return if @card.errors.any?
      @stage = StageDirector.stage_index stage

      @subphase = :before
      @card.run_callbacks :"#{stage}_stage"
      # in the store stage it can be necessary that
      # other subcards must be saved before this card gets saved
      if stage == :store
        store &block
      else
        run_subdirector_stages stage
      end
      @subphase = :after
    rescue => e
      rescue_event e
    end

    def run_subdirector_stages stage
      @subdirectors.each do |subdir|
        subdir.catch_up_to_stage stage
      end
    end
  end


  class StageSubdirector < StageDirector
    def initialize card, opts={}
      super card, opts, true
      assign_act
    end

    private

    def store &block
      store_with_subcards do
        @card.skip_phases = true
        @card.save! validate: false
      end
    end
  end
end


