require 'spec_helper'

RSpec.describe SimpleFeed::Providers::Base::Provider do
  context 'class methods' do
    it 'should correctly convert class names' do
      expect(subject.class.class_to_registry(SimpleFeed::Providers::Redis::Provider)).to eq(:redis)
    end
  end

  context 'inheritance' do
    class TestProvider < SimpleFeed::Providers::Base::Provider
      def transform_response(user_id, result)
        case result
          when Symbol
            result.to_s.upcase.to_sym
          when Hash
            result.each { |k, v| result[k] = transform_response(user_id, v) }
          when String
            if result =~ /^\d+\.\d+$/
              result.to_f
            elsif result =~ /^\d+$/
              result.to_i
            else
              result
            end
          else
            raise TypeError, 'Invalid response type'
        end
      end

      SimpleFeed::Providers::REQUIRED_METHODS.each do |m|
        define_method(m) do |**opts, &block|
          puts "calling into method #{m}(#{opts})"
        end
      end

      # Override store
      def store(user_ids:, **opts)
        with_response_batched(user_ids) do |key, response|
          response.for(key, :add)
        end
      end

      def remove(user_ids:, **opts)
        with_response_batched(user_ids) do |key, response|
          response.for(key, { total: 'unknown' })
        end
      end

      def batch_size
        2
      end
    end
  
    let(:provider) { TestProvider.new }
    let(:feed) { SimpleFeed.define(:test, provider: provider) }
    let(:user_ids) { [1, 2, 3, 4] }

    before do
      provider.feed = Hashie::Mash.new({ namespace: :tp })
    end

    context 'transforming values' do
      context '#store' do
        let(:response) { feed.for(user_ids).store(value: true, at: Time.now) }
        it 'should transform result' do
          expect(response.result.values.all? { |v| v == :ADD }).to be_truthy
        end
      end

      context '#remove' do
        let(:ts) { Time.now }
        before do
          feed.for(user_ids).store(event: SimpleFeed::Event.new(:hello, ts))
        end
        let(:response) { feed.for(user_ids).remove(value: :hello, at: ts) }
        it 'should transform the result' do
          #puts response.result.inspect
        end
      end
    end
  end
end