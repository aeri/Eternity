defmodule Usuario do
	defp mutex(requesting_critical_section, our_sequence_number, highest_sequence_number, reply_deferred, outstanding_reply) do
		receive do
			{pid, :chooseSeqNum}  ->
				new_requesting_critical_section = true
				new_our_sequence_number = highest_sequence_number + 1
				send pid, {new_our_sequence_number, :ok} 
				mutex(new_requesting_critical_section, new_our_sequence_number, highest_sequence_number, reply_deferred, outstanding_reply)
			{pid, n, :asignOutstandingReply} ->
				new_outstanding_reply = n - 1
				send(pid, {:ok})
				mutex(requesting_critical_section, our_sequence_number, highest_sequence_number, reply_deferred, new_outstanding_reply)
			{pid, :checkOutstandingReply} ->
				send(pid, {outstanding_reply, :ok})
				mutex(requesting_critical_section, our_sequence_number, highest_sequence_number, reply_deferred, outstanding_reply)
            {pid, :release} ->
				new_requesting_critical_section = false
				send(pid, {:ok})
				mutex(new_requesting_critical_section, our_sequence_number, highest_sequence_number, reply_deferred, outstanding_reply)
			{pid, j, :checkDeferred} ->
				send(pid, {Enum.at(reply_deferred,j-1), :ok})
				mutex(requesting_critical_section, our_sequence_number, highest_sequence_number, reply_deferred, outstanding_reply)
			{pid, j, value, :modifyDeferred} ->
				new_reply_deferred = List.replace_at(reply_deferred, j-1, value)
				send(pid, {:ok})
				mutex(requesting_critical_section, our_sequence_number, highest_sequence_number, new_reply_deferred, outstanding_reply)
			{pid, k, :maxSeq} ->
				if k > highest_sequence_number do
					new_highest_sequence_number = k
					send(pid, {:ok})
					mutex(requesting_critical_section, our_sequence_number, new_highest_sequence_number, reply_deferred, outstanding_reply)
				else
					send(pid, {:ok})
					mutex(requesting_critical_section, our_sequence_number, highest_sequence_number, reply_deferred, outstanding_reply)
				end
			{pid, k, j, me, :checkDeferIt} ->
				if requesting_critical_section and ((k > our_sequence_number) or (k == our_sequence_number and j > me)) do
					send(pid, {true, :ok})
				else
					send(pid, {false, :ok})
				end
				mutex(requesting_critical_section, our_sequence_number, highest_sequence_number, reply_deferred, outstanding_reply)
			{pid, direccion, :subOutstandingReply} ->
				new_outstanding_reply = outstanding_reply - 1
				if new_outstanding_reply == 0 do
					send {:distributed, direccion}, {:ok_0}
				end
				send pid, {:ok}
				mutex(requesting_critical_section, our_sequence_number, highest_sequence_number, reply_deferred, new_outstanding_reply)
		end
	end

	defp distributed_critical_section(mypid, num, lista, mydireccion) do
		mensaje = String.trim(IO.gets "Introduce mensaje\n") # Se guarda el mensaje sin un salto de línea al final
		send mypid, {self(), :chooseSeqNum}
		receive do
			{numSeq, :ok} -> # Se queda bloqueado esperando un signal (:ok) del proceso mutex
				send mypid, {self(), length(lista), :asignOutstandingReply} 
				receive do
					{:ok} ->
                        for {id, direccion} <- lista do
                            if id != num do
                                send {:receive_request, direccion}, {mydireccion, num, numSeq, :request}
                            end
                        end
                        receive do
                            {:ok_0} -> # Se espera a que haya una respuesta (:reply) del resto de nodos
                                for {id, direccion} <- lista do
                                    if id != num do
                                        send {:show_messages, direccion}, {mydireccion, mensaje, :mensaje} # Al entrar a la seccion critica manda el mensaje a todos los nodos
                                    end
                                end
                                send mypid, {self(),:release}
                                receive do
                                    {:ok} ->
                                        for {id, direccion} <- lista do
                                            send mypid, {self(), id, :checkDeferred}
                                            receive do
                                                {value, :ok} ->
                                                    if value do
                                                        send mypid, {self(), id, false, :modifyDeferred}
                                                        receive do
                                                            {:ok} ->
                                                                send {:receive_reply, direccion}, {:reply} # Mandar un mensaje de REPLY al nodo
                                                        end
                                                    end
                                            end
                                        end
                                        distributed_critical_section(mypid, num, lista, mydireccion)
                                    end
                            end
                    end
            end
    end
	defp receive_request_messages(mypid, num) do
		receive do
			{node_dir, j, k, :request} ->
				send mypid, {self(), k, :maxSeq}
				receive do
					{:ok} ->
                        send mypid, {self(), k, j, num, :checkDeferIt}
                        receive do
                            {defer_it, :ok} ->
                                if defer_it do
                                    send mypid, {self(), j, true, :modifyDeferred}
                                    receive do
                                        {:ok} ->
                                            receive_request_messages(mypid, num)
                                    end
                                else
                                    send {:receive_reply, node_dir}, {:reply}
                                    receive_request_messages(mypid, num)
                                end
                        end
                end
        end
    end

	defp receive_reply_messages(mypid) do
		receive do
			{:reply} ->
                send mypid, {self(), Node.self(),:subOutstandingReply}
                receive do
                    {:ok} ->
                        receive_reply_messages(mypid)
                end
        end
	end
	
	defp show_messages() do
		receive do
			{direccion, mensaje, :mensaje} ->
				IO.puts to_string(direccion) <> ": " <> mensaje
		end
		show_messages()
	end
	
	def init(lista, mynum) do
        mypid = spawn(fn->mutex(false, false, 0, List.duplicate(false, length(lista)), length(lista) - 1)end)
        spawn(fn->
                Process.register(self(), :distributed)
                distributed_critical_section(mypid, mynum, lista, Node.self())end)
        spawn(fn->
                Process.register(self(), :receive_request)
                receive_request_messages(mypid, mynum)end)
        spawn(fn->
                Process.register(self(), :receive_reply)
                receive_reply_messages(mypid)end)
        Process.register(self(), :show_messages)
        show_messages()
    end
end
