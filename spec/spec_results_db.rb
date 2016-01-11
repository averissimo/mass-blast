require_relative 'spec_helper'
require_relative '../src/results_db'
require 'logger'

#
#
RSpec.describe ResultsDB do

  create_el = proc do |identity, coverage, evalue, qseq, db_name|
    { DB::IDENTITY => identity,
      DB::COVERAGE => coverage,
      DB::EVALUE => evalue,
      'qseq' => qseq,
      'db' => db_name
    }
  end

  #
  #
  it 'should add all elements' do
    results = ResultsDB.new 40
    #
    results.add(1, create_el.call('50', '40', '10E-20', 'aaa', 'blackberry'))
    results.add(2, create_el.call('50', '40', '10E-20', 'aab', 'blackberry'))
    results.add(3, create_el.call('50', '40', '10E-20', 'aaa', 'blackberry'))

    expect(results.size).to eq(3)
  end

  it 'should prune duplicate qseq elements' do
    results = ResultsDB.new 40
    #
    results.add(1, create_el.call('30', '40', '10E-20', 'aaa', 'blackberry'))
    results.add(2, create_el.call('50', '40', '10E-20', 'aab', 'blackberry'))
    results.add(3, create_el.call('50', '40', '10E-20', 'aaa', 'blackberry'))
    results.add(4, create_el.call('70', '40', '10E-20', 'aaa', 'blackberry'))

    results.remove_identical('qseq')

    expect(results.size).to eq(2)
  end

  #
  it 'should prune duplicate qseq elements and use the database' do
    results = ResultsDB.new 40
    #
    results.add(1, create_el.call('30', '40', '10E-20', 'aaa', 'blackberry'))
    results.add(2, create_el.call('50', '40', '10E-20', 'aab', 'blackberry'))
    results.add(3, create_el.call('50', '40', '10E-20', 'aaa', 'blackberry'))
    results.add(4, create_el.call('70', '40', '10E-20', 'aaa', 'blackberry'))
    results.add(5, create_el.call('70', '40', '10E-20', 'aaa', 'bilberry'))

    results.remove_identical('qseq')

    expect(results.size).to eq(3)
  end

  #
  #
  it 'should add only elements with different id' do
    results = ResultsDB.new 40
    #
    results.add('1', create_el.call('50', '40', '10E-20', 'aaa', 'blackberry'))
    #
    results.add('2', create_el.call('50', '40', '10E-20', 'aab', 'blackberry'))
    results.add('2', create_el.call('50', '40', '10E-20', 'aab', 'blackberry'))
    results.add('2', create_el.call('50', '40', '10E-20', 'aab', 'blackberry'))
    results.add('2', create_el.call('50', '40', '10E-20', 'aab', 'blackberry'))
    #
    results.add('1', create_el.call('50', '40', '10E-20', 'aaa', 'blackberry'))
    #
    results.add('3', create_el.call('50', '40', '10E-20', 'aaa', 'blackberry'))
    results.add('3', create_el.call('50', '40', '10E-20', 'aaa', 'blackberry'))
    results.add('3', create_el.call('50', '40', '10E-20', 'aaa', 'blackberry'))
    results.add('3', create_el.call('50', '40', '10E-20', 'aaa', 'blackberry'))
    results.add('3', create_el.call('50', '40', '10E-20', 'aaa', 'blackberry'))
    #
    results.add('1', create_el.call('50', '40', '10E-20', 'aaa', 'blackberry'))
    results.add('1', create_el.call('50', '40', '10E-20', 'aaa', 'blackberry'))
    results.add('1', create_el.call('50', '40', '10E-20', 'aaa', 'blackberry'))
    #
    results.add('2', create_el.call('50', '40', '10E-20', 'aab', 'blackberry'))
    results.add('2', create_el.call('50', '40', '10E-20', 'aab', 'blackberry'))
    results.add('2', create_el.call('50', '40', '10E-20', 'aab', 'blackberry'))
    #
    expect(results.size).to eq(3)
  end
end
