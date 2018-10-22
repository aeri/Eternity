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

  def fn1(pid) do
    time1 = :os.system_time(:millisecond)
    perfectos = encuentra_perfectos({1, 10000})
    time2 = :os.system_time(:millisecond)    
    send(pid, {time2 - time1, perfectos})
  end
  
  def servidor() do
    receive do
      {pid, :perfectos} -> spawn(fn->fn1(pid)end)
                    
      {pid, :perfectos_ht} ->	time1 = :os.system_time(:millisecond)
      							if :rand.uniform(100)>60, do: Process.sleep(round(:rand.uniform(100)/100 * 2000))
								perfectos = encuentra_perfectos({1, 10000})
								time2 = :os.system_time(:millisecond)			
								send(pid, {time2 - time1, perfectos})
    end    
    servidor()
  end 
end

pid = spawn(Perfectos, :servidor, []) 