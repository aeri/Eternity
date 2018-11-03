# AUTOR: Rafael Tolosana Calasanz
# NIAs: -
# FICHERO: para_perfectos_cliente.exs
# FECHA: 21 de septiembre de 2018
# TIEMPO: -
# DESCRIPCI'ON: c'oodigo para el cliente

defmodule Perfectos_cliente do
  def request(server_pid, tipo_server) do
    time1 = :os.system_time(:millisecond) 
    send(server_pid, {self(), tipo_server})
    receive do
      {tex, lista_perfectos} -> 
      							time2 = :os.system_time(:millisecond) 
								mi_pid = self()
								IO.inspect(lista_perfectos, label: "Los cuatro numeros perfectos son")
								IO.inspect(mi_pid, label: "Tiempo de ejecucion: #{tex}")
								IO.inspect(mi_pid, label: "Tiempo total: #{time2 - time1}")
								if (time2 - time1) > (tex * 2), do: IO.puts("Violacion del QoS")
    end
  end
  
  
  defp lanza_request(server_pid, 1, tipo_server) do
  	spawn(Perfectos_cliente, :request, [server_pid, tipo_server])
  end
  
  defp lanza_request(server_pid, n, tipo_server) when n > 1 do
  	spawn(Perfectos_cliente, :request, [server_pid, tipo_server])
	lanza_request(server_pid, n - 1, tipo_server)
  end
  
  def genera_workload(server_pid, tipo_escenario) do
  	case tipo_escenario do
	  :uno -> 		lanza_request(server_pid, 1, :perfectos)
	  :dos -> 		lanza_request(server_pid, System.schedulers, :perfectos)
	  :tres -> 		lanza_request(server_pid, System.schedulers*2 + 2, :perfectos)
	  :cuatro -> 	lanza_request(server_pid, System.schedulers*2 + 2, :perfectos_ht)
	  _ ->			IO.puts "Error!"
	end
  end
  
  def cliente(server_pid, tipo_escenario) do
	genera_workload(server_pid, tipo_escenario)
	:timer.sleep(2000)
	cliente(server_pid, tipo_escenario)
  end
end

Perfectos_cliente.cliente(pid, :uno)
