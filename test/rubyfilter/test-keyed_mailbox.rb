#!/usr/bin/env ruby
#--
#   Copyright (C) 2002, 2003 Matt Armstrong.  All rights reserved.
#
#   Permission is granted for use, copying, modification,
#   distribution, and distribution of modified versions of this work
#   as long as the above copyright notice is included.
#

require 'test/rubyfilter/testbase'
require 'rfilter/keyed_mailbox'
require 'rmail/message'
require 'ftools'

module RFilter
  module Test
    class TestRFilter_KeyedMailbox < TestBase
      def stock_message
        message = RMail::Message.new
        message.header['to'] = 'bob@example.net'
        message.header['from'] = 'sally@example.net'
        message.header['subject'] = 'rutabaga'
        message.body = 'message body'
        return message
      end

      def test_s_new
        assert_exception(ArgumentError) {
          RFilter::KeyedMailbox.new
        }
        obj = RFilter::KeyedMailbox.new(scratch_filename('test'))
        assert_instance_of(RFilter::KeyedMailbox, obj)
        assert_respond_to(:save, obj)
        assert_respond_to(:delete, obj)
        assert_respond_to(:expire, obj)
      end

      def test_path
        dir = scratch_filename('test_path_dir')
        box = RFilter::KeyedMailbox.new(dir)
        assert_equal(dir, box.path)
        assert(box.path.frozen?)
      end

      def test_save
        dir = scratch_filename('queue')
        message = stock_message

        queue = RFilter::KeyedMailbox.new(dir)
        key = queue.save(message)
        assert_match(/^[A-F\d][A-F\d-]+[A-F\d]$/, key)
      end

      def test_retrieve
        dir = scratch_filename('queue')
        message = stock_message

        queue = RFilter::KeyedMailbox.new(dir)
        key = queue.save(message)
        filename = queue.retrieve(key)
        assert_equal(File.join(dir, 'new'), File.dirname(filename))
        assert(File::exists?(filename))

        filename2 = File.join(dir, 'cur', File::basename(filename) + ':2')
        File::move(filename, filename2)
        assert_equal(filename2, queue.retrieve(key))

        File::delete(filename2)
        assert_equal(nil, queue.retrieve(key))

        File::delete(File.join(dir, '.index', key))
        assert_equal(nil, queue.retrieve(key))
      end

      def test_delete
        dir = scratch_filename('queue')
        message = stock_message

        queue = RFilter::KeyedMailbox.new(dir)
        key = queue.save(message)

        index = File.join(dir, '.index', key)
        file = queue.retrieve(key)
        assert(File::exists?(index))
        assert(File::exists?(file))
        queue.delete(key)
        assert_equal(false, File::exists?(index))
        assert_equal(false, File::exists?(file))

        assert_no_exception {
          queue.delete('ABDFAABBDF')
        }
      end

      def test_expire
        dir = scratch_filename('queue')
        message = stock_message

        queue = RFilter::KeyedMailbox.new(dir)
        key = queue.save(message)
        assert_not_nil(queue.retrieve(key))
        queue.expire(1)
        assert_not_nil(queue.retrieve(key))
        queue.expire(0)
        assert_equal(nil, queue.retrieve(key))
      end

      def test_each_key
        dir = scratch_filename('queue')
        message = stock_message

        # Create a new queue with 10 separate messages
        queue = RFilter::KeyedMailbox.new(dir)
        keys = [0..10].collect {
          queue.save(message)
        }

        # Ensure unique keys are returned
        assert_equal(keys.length, keys.uniq.length, "duplicate key found")

        # Ensure each and every key is enumerated exactly once
        keys_copy = keys.dup
        queue.each_key { |key|
          assert(keys_copy.include?(key),
                 "each_key returned a duplicate or random key")
          keys_copy.delete(key)
        }
        assert(keys_copy.empty?, "not all keys were enumerated")

        # Delete all the keys and make sure none are enumerated
        keys.each { |key|
          queue.delete(key)
        }
        queue.each_key { |key|
          assert(false, "enumerated a key after they were all deleted")
        }
      end

    end
  end
end
