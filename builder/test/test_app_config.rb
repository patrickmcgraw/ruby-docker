# Copyright 2017 Google Inc. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require "minitest/autorun"
require "fileutils"

require_relative "../generate_dockerfile/files/app_config.rb"


class TestAppConfig < ::Minitest::Test
  EMPTY_HASH = {}.freeze
  EMPTY_ARRAY = [].freeze
  EMPTY_STRING = ''.freeze

  TEST_DIR = ::File.dirname __FILE__
  CASES_DIR = ::File.join TEST_DIR, "app_config"
  TMP_DIR = ::File.join TEST_DIR, "tmp"

  def setup_test dir: nil, config: nil, config_file: nil, project: nil
    ::Dir.chdir TEST_DIR
    ::FileUtils.rm_rf TMP_DIR
    if dir
      full_dir = ::File.join CASES_DIR, dir
      ::FileUtils.cp_r full_dir, TMP_DIR
    else
      ::FileUtils.mkdir TMP_DIR
      ::ENV["GAE_APPLICATION_YAML_PATH"] = config_file
      ::ENV["PROJECT_ID"] = project
      if config
        config_path = ::File.join TMP_DIR, config_file || "app.yaml"
        ::File.open config_path, "w" do |file|
          file.write config
        end
      end
    end
    @app_config = AppConfig.new TMP_DIR
  end

  def test_empty_directory
    setup_test
    assert_equal TMP_DIR, @app_config.workspace_dir
    assert_equal "./app.yaml", @app_config.app_yaml_path
    assert_equal "(unknown)", @app_config.project_id
    assert_equal "default", @app_config.service_name
    assert_equal EMPTY_HASH, @app_config.env_variables
    assert_equal EMPTY_ARRAY, @app_config.cloud_sql_instances
    assert_equal EMPTY_ARRAY, @app_config.build_scripts
    assert_equal EMPTY_HASH, @app_config.runtime_config
    assert_equal "exec bundle exec rackup -p $PORT", @app_config.entrypoint
    assert_equal EMPTY_ARRAY, @app_config.install_packages
    assert_equal EMPTY_STRING, @app_config.ruby_version
    refute @app_config.has_gemfile
  end

  def test_basic_app_yaml
    config = <<~CONFIG
      env: flex
      runtime: ruby
      entrypoint: bundle exec bin/rails s
      env_variables:
        VAR1: value1
        VAR2: value2
      beta_settings:
        cloud_sql_instances: cloud-sql-instance-name
      runtime_config:
        foo: bar
        packages: libgeos
      lifecycle:
        build: bundle exec rake hello
    CONFIG
    setup_test config: config
    assert_equal({"VAR1" => "value1", "VAR2" => "value2"},
                 @app_config.env_variables)
    assert_equal ["cloud-sql-instance-name"], @app_config.cloud_sql_instances
    assert_equal ["bundle exec rake hello"], @app_config.build_scripts
    assert_equal "exec bundle exec bin/rails s", @app_config.entrypoint
    assert_equal ["libgeos"], @app_config.install_packages
    assert_equal "bar", @app_config.runtime_config["foo"]
  end

  def test_complex_entrypoint
    config = <<~CONFIG
      env: flex
      runtime: ruby
      entrypoint: cd myapp; bundle exec bin/rails s
    CONFIG
    setup_test config: config
    assert_equal "cd myapp; bundle exec bin/rails s", @app_config.entrypoint
  end

  def test_entrypoint_already_exec
    config = <<~CONFIG
      env: flex
      runtime: ruby
      entrypoint: exec bundle exec bin/rails s
    CONFIG
    setup_test config: config
    assert_equal "exec bundle exec bin/rails s", @app_config.entrypoint
  end

  def test_rails_default_build
    setup_test dir: "rails"
    assert_equal ["bundle exec rake assets:precompile || true"],
                 @app_config.build_scripts
  end

  def test_ruby_version
    setup_test dir: "ruby-version"
    assert_equal "2.0.99", @app_config.ruby_version
  end

  def test_gemfile
    setup_test dir: "gemfile"
    assert @app_config.has_gemfile
  end
end