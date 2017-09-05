workspace()

using SimJulia
using ResumableFunctions

@resumable function client(sim::Simulation, res::Resource, i::Int, prior::Int)
  println("$(now(sim)), client $i is waiting")
  @yield Request(res, priority=prior)
  println("$(now(sim)), client $i is being served")
  @yield Timeout(sim, rand())
  println("$(now(sim)), client $i has been served")
  @yield Release(res)
end

@resumable function generate(sim::Simulation, res::Resource)
  for i in 1:10
    @coroutine client(sim, res, i, 10-i)
    @yield Timeout(sim, 0.5*rand())
  end
end

sim = Simulation()
res = Resource(sim, 2; level=1)
@coroutine generate(sim, res)
run(sim)

@resumable function my_consumer(sim::Simulation, con::Container)
  for i in 1:10
    amount = 3*rand()
    println("$(now(sim)), consumer is demanding $amount")
    @yield Timeout(sim, 1.0*rand())
    get_ev = Get(con, amount)
    val = @yield get_ev | Timeout(sim, rand())
    if val[get_ev].state == SimJulia.triggered
      println("$(now(sim)), consumer is being served, level is ", con.level)
      @yield Timeout(sim, 5.0*rand())
    else
      println("$(now(sim)), consumer has timed out")
      cancel(con, get_ev)
    end
  end
end

@resumable function my_producer(sim::Simulation, con::Container)
  for i in 1:10
    amount = 2*rand()
    println("$(now(sim)), producer is offering $amount")
    @yield Timeout(sim, 1.0*rand())
    @yield Put(con, amount)
    println("$(now(sim)), producer is being served, level is ", con.level)
    @yield Timeout(sim, 5.0*rand())
  end
end

sim = Simulation()
con = Container(sim, 10.0; level=5.0)
@coroutine my_consumer(sim, con)
@coroutine my_producer(sim, con)
run(sim)

 
