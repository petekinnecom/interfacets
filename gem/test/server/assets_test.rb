# frozen_string_literal: true

require "tmpdir"
require_relative "../test_helper"

module Interfacets
  module Server
    class AssetsTest < InterfacetsTest
      def test_classifier_finds_modules_and_classes
        code = <<~RUBY
          module A
            module B
              class C; end
            end
            class D < E; end
          end
          class F; end
        RUBY

        classifier = Assets::Classifier.new(code)
        consts = classifier.consts

        assert_equal 5, consts.size

        assert_equal "A", consts[0].full_name
        assert_equal :module, consts[0].type
        assert_nil consts[0].parent

        assert_equal "A::B", consts[1].full_name
        assert_equal :module, consts[1].type

        assert_equal "A::B::C", consts[2].full_name
        assert_equal :class, consts[2].type

        assert_equal "A::D", consts[3].full_name
        assert_equal :class, consts[3].type
        assert_equal "E", consts[3].parent

        assert_equal "F", consts[4].full_name
        assert_equal :class, consts[4].type
      end

      def test_classifier_handles_complex_constant_paths
        code = <<~RUBY
          module Foo::Bar
            class Baz::Qux < Core::Base; end
          end
        RUBY

        classifier = Assets::Classifier.new(code)
        consts = classifier.consts

        assert_equal 2, consts.size
        assert_equal "Foo::Bar", consts[0].full_name
        assert_equal "Foo::Bar::Baz::Qux", consts[1].full_name
        assert_equal "Core::Base", consts[1].parent
      end

      def test_serializer_fs_map
        file_mock = Minitest::Mock.new
        file_mock.expect :read, "content 1", ["path1.rb"]
        file_mock.expect :read, "content 2", ["path2.rb"]

        serializer = Assets::Serializer.new(paths: ["path1.rb", "path2.rb"], file: file_mock)
        fs_map = serializer.as_json[:fs_map]

        assert_equal({ "path1.rb" => "content 1", "path2.rb" => "content 2" }, fs_map)
        file_mock.verify
      end

      def test_serializer_const_map
        code1 = "class A; end"
        code2 = "module B; class C; end; end"
        
        file_mock = Minitest::Mock.new
        file_mock.expect :read, code1, ["a.rb"]
        file_mock.expect :read, code2, ["b.rb"]

        serializer = Assets::Serializer.new(paths: ["a.rb", "b.rb"], file: file_mock)
        const_map = serializer.as_json[:const_map]

        assert_equal ["a.rb"], const_map["A"]
        assert_equal ["b.rb"], const_map["B"]
        assert_equal ["b.rb"], const_map["B::C"]
      end

      def test_serializer_scaffolding
        code = <<~RUBY
          module M
            class C < P; end
          end
          class P; end
        RUBY

        file_mock = Minitest::Mock.new
        file_mock.expect :read, code, ["test.rb"]

        serializer = Assets::Serializer.new(paths: ["test.rb"], file: file_mock)
        scaffolding = serializer.as_json[:scaffolding]

        # Order matters for scaffolding (dependencies first)
        # P should be before M::C
        # M should be before M::C
        
        assert_match(/module M/, scaffolding[0])
        assert_match(/class P/, scaffolding[1])
        assert_match(/class M::C < P/, scaffolding[2])
        
        scaffolding.each do |s|
          assert_match(/include Interfacets::Client::Assets::AutoloadHook/, s)
        end
      end

      def test_resolve_const_name
        code = <<~RUBY
          module A
            class B; end
            module C
              class D < B; end
            end
          end
        RUBY
        
        file_mock = Object.new
        def file_mock.read(_path)
          <<~RUBY
            module A
              class B; end
              module C
                class D < B; end
              end
            end
          RUBY
        end

        serializer = Assets::Serializer.new(paths: ["test.rb"], file: file_mock)
        # Testing private method via send for thoroughness if needed, 
        # but scaffolding test above already covers it.
        # Let's check if D correctly identifies A::B as parent.
        
        scaffolding = serializer.as_json[:scaffolding]
        d_scaffold = scaffolding.find { |s| s.include?("class A::C::D") }
        assert_match(/class A::C::D < A::B/, d_scaffold)
      end

      def test_classifier_empty_code
        classifier = Assets::Classifier.new("")
        assert_empty classifier.consts
      end

      def test_serializer_empty_paths
        serializer = Assets::Serializer.new(paths: [])
        json = serializer.as_json
        assert_empty json[:fs_map]
        assert_empty json[:const_map]
        assert_empty json[:scaffolding]
      end

      def test_resolve_const_name_missing
        file_mock = Object.new
        def file_mock.read(_path); "class A; end"; end
        serializer = Assets::Serializer.new(paths: ["test.rb"], file: file_mock)
        
        # Should return the name string if it can't resolve to a Const
        assert_equal "Unknown", serializer.send(:resolve_const_name, "A", "Unknown")
      end

      def test_bundle
        Dir.mktmpdir do |dir|
          subdir = File.join(dir, "app")
          Dir.mkdir(subdir)
          file_path = File.join(subdir, "component.rb")
          File.write(file_path, "class MyComponent; end")

          bundle = Assets.bundle(dirs: [subdir], registry: nil)
          
          assert bundle.key?(:fs_map)
          assert bundle.key?(:const_map)
          assert bundle.key?(:scaffolding)
          
          assert_equal "class MyComponent; end", bundle[:fs_map][file_path]
          assert_equal [file_path], bundle[:const_map]["MyComponent"]
          assert bundle[:scaffolding].any? { |s| s.include?("class MyComponent") }
        end
      end
    end
  end
end
