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

  def assign([wpid|tail], tarea, cliente, time1, num) do 
    if num != 3 && length([wpid|tail]) != 0 do
    	send(wpid, {self(), tarea, cliente, 1, 10000})
    	assign(tail, tarea, cliente, time1, num+1)
    else
        tail
    end
  end
    
  def master(lista, tarealeer, tareaenviar, tareas) do
    receive do
      {pid_c, :perfectos_ht} ->	time1 = :os.system_time(:millisecond)
	       listadespues = assign(lista, tareaenviar, pid_c, time1, 1)
    	       master(listadespues, tarealeer, tareaenviar+1, tareas++[tareaenviar])
      {wpid, numtarea, cliente, lista, tiempo, :worker} -> 
      						 if length(tareas) != length(List.delete(tareas,numtarea)) do
						 time2 = :os.system(:millisecond)
                                                 send(cliente, {time2 - tiempo, lista})
						 List.insert(lista, -1, wpid)
    						 master(lista, tarealeer+1, tareaenviar, List.delete(tareas, numtarea))
						 else
						 master(lista, tarealeer, tareaenviar, tareas)
						 end
    end
  end 
  def worker() do
    receive do
      {pid, tarea, cliente, inicio, fin, tiempo} -> if :rand.uniform(100)>60, do: Process.sleep(round(:rand.uniform(100)/100 * 2000))
    			send(pid, {self(), tarea, cliente, encuentra_perfectos({inicio, fin}), :worker})
    end
  end
  def master_init(lista) do
    master(lista, lista, 1, [])
  end
end

pid = spawn(Perfectos, :master, []) 
