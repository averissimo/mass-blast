require_relative 'test_helper'
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

  create_db = proc do |min = 40, max = 100|
    ResultsDB.new min, max, './', './', false, nil
  end

  #
  #
  it 'should add all elements' do
    results = create_db.call(40)
    #
    results.add(nil, create_el.call('50', '40', '10E-20', 'aaa', 'blackberry'))
    results.add(nil, create_el.call('50', '40', '10E-20', 'aab', 'blackberry'))
    results.add(nil, create_el.call('50', '40', '10E-20', 'aaa', 'blackberry'))

    expect(results.size).to eq(3)
  end

  it 'should prune duplicate qseq elements' do
    results = create_db.call(40)
    #
    results.add(nil, create_el.call('30', '40', '10E-20', 'aaa', 'blackberry'))
    results.add(nil, create_el.call('50', '40', '10E-20', 'aab', 'blackberry'))
    results.add(nil, create_el.call('50', '40', '10E-20', 'aaa', 'blackberry'))
    results.add(nil, create_el.call('70', '40', '10E-20', 'aaa', 'blackberry'))

    results.remove_identical('qseq')

    expect(results.size).to eq(2)
  end

  #
  it 'should prune duplicate qseq elements and use the database' do
    results = create_db.call(40)
    #
    results.add(nil, create_el.call('30', '40', '10E-20', 'aaa', 'blackberry'))
    results.add(nil, create_el.call('50', '40', '10E-20', 'aab', 'blackberry'))
    results.add(nil, create_el.call('50', '40', '10E-20', 'aaa', 'blackberry'))
    results.add(nil, create_el.call('70', '40', '10E-20', 'aaa', 'blackberry'))
    results.add(nil, create_el.call('70', '40', '10E-20', 'aaa', 'bilberry'))
    #
    results.remove_identical('qseq')
    expect(results.size).to eq(3)
  end

  it 'should compare well between DB items -- identity' do
    db1 = DB.new create_el.call('30', '40', '10E-20', 'aaa', 'blackberry')
    db2 = DB.new create_el.call('40', '40', '10E-20', 'aaa', 'blackberry')
    expect(db1).to be < db2
  end

  it 'should compare well between DB items -- coverage' do
    db1 = DB.new create_el.call('30', '50', '10E-20', 'aaa', 'blackberry')
    db2 = DB.new create_el.call('30', '40', '10E-20', 'aaa', 'blackberry')
    expect(db1).to be > db2
  end

  it 'should compare well between DB items -- evalue' do
    db1 = DB.new create_el.call('30', '40', '0', 'aaa', 'blackberry')
    db2 = DB.new create_el.call('30', '40', '10E-20', 'aaa', 'blackberry')
    expect(db1).to be > db2
  end

  it 'should compare well between DB items -- same' do
    db1 = DB.new create_el.call('30', '40', '10E-20', 'aaa', 'blackberry')
    db2 = DB.new create_el.call('30', '40', '10E-20', 'aaa', 'blackberry')
    expect(db1).to eq(db2)
  end
  #
  #
  it 'should only take the best one' do
    results = create_db.call(40)
    #
    results.add('i', create_el.call('30', '40', '10E-20', 'aaa', 'blackberry'))
    results.add('i', create_el.call('50', '40', '10E-20', 'aab', 'blackberry'))
    results.add('i', create_el.call('50', '40', '10E-20', 'aaa', 'blackberry'))
    results.add('i', create_el.call('70', '40', '10E-20', 'aaa', 'blackberry'))
    #
    expect(results.size).to eq(1)
    expect(results['i'].identity).to eq(70)
    #
  end

  #
  #
  it 'should add only elements with different id' do
    results = create_db.call(40)
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
