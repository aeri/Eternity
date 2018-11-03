# AUTOR: Rafael Tolosana Calasanz
# NIAs: -
# FICHERO: para_perfectos.exs
# FECHA: 21 de septiembre de 2018
# TIEMPO: -
# DESCRIPCI'ON: c'oodigo para el servidor / worker

defmodule Perfectos do

  defp suma_divisores_propios(n, 1) do
    1
  end
  
  defp suma_divisores_propios(n, i) when i > 1 do
    if rem(n, i)==0, do: i + suma_divisores_propios(n, i - 1), else: suma_divisores_propios(n, i - 1)
  end
  
  def suma_divisores_propios(n) do
    suma_divisores_propios(n, n - 1)
  end
  
  def es_perfecto?(1) do
    false
  end
  
  def es_perfecto?(a) when a > 1 do
    suma_divisores_propios(a) == a
  end
 
  defp encuentra_perfectos({a, a}, queue) do
    if es_perfecto?(a), do: [a | queue], else: queue
  end
  defp encuentra_perfectos({a, b}, queue) when a != b do
    encuentra_perfectos({a, b - 1}, (if es_perfecto?(b), do: [b | queue], else: queue))
  end

  def encuentra_perfectos({a, b}) do
    encuentra_perfectos({a, b}, [])
  end 

  def assign([{w_pid,t}|tail], tarea) do
    send(w_pid, {tarea, 1, 10000})
    assign(tail, tarea)
  end
  
  def assign([], tarea) do
    IO.puts("Se ha mandado la tarea")
  end

  def fn1(inicio, fin, tarea, pid) do
    if :rand.uniform(100)>60, do: Process.sleep(round(:rand.uniform(100)/100 * 2000))
    send(pid, {tarea, encuentra_perfectos({inicio, fin}), :worker})
  end

  def collect(tarea, pid, tiempo) do
  	receive do
	   {numtarea, lista_perfectos, :worker} -> if tarea==numtarea do 
		time2 = :os.system_time(:millisecond)			
	   	send(pid, {lista_perfectos, time2 - tiempo})
	   else
	   	collect(tarea, pid, tiempo)
	   end
	end
  end
    
  def master(lista, tarea) do
    receive do
      {pid_c, :perfectos_ht} ->	time1 = :os.system_time(:millisecond)
	       assign(lista, tarea)
	       spawn(fn->collect(tarea, pid_c, time1)end)
	       _ = tarea + 1
	    end    
    master(lista, tarea)
  end 
  def worker() do
    receive do
      {pid, tarea, inicio, fin} -> spawn(fn->fn1(inicio, fin, tarea, pid)end)
    end
  end
  def master_init(lista) do
    master(lista, 1)
  end
end

pid = spawn(Perfectos, :master, []) 
