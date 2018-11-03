defmodule Usuario do
	defp mutex(requesting_critical_section, our_sequence_number, highest_sequence_number, reply_deferred, outstanding_reply) do
		receive do
			{pid, :chooseSeqNum}  ->
				new_requesting_critical_section = true
				new_our_sequence_number = highest_sequence_number + 1
				send(pid, {new_our_sequence_number, :ok})
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
				send(pid, {reply_deferred[j], :ok})
				mutex(requesting_critical_section, our_sequence_number, highest_sequence_number, reply_deferred, outstanding_reply)
			{pid, j, value, :modifyDeferred} ->
				new_reply_deferred = replace_at(reply_deferred, j, value)
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
				if requesting_critical_section and ((k > our_sequence_number) or (k = our_sequence_number and j > me)) do
					send(pid, {true, :ok})
				else
					send(pid, {false, :ok})
				end
				mutex(requesting_critical_section, our_sequence_number, highest_sequence_number, reply_deferred, outstanding_reply)
			{pid, :subOutstandingReply} ->
				new_outstanding_reply = outstanding_reply - 1
				if new_outstanding_reply == 0 do
					send(pid, {:ok_0})
				end
				send(pid, {:ok})
				mutex(requesting_critical_section, our_sequence_number, highest_sequence_number, reply_deferred, new_outstanding_reply)
		end
	end

	defp distributed_critical_section(mypid, num, lista) do
		mensaje = IO.gets "Introduce mensaje\n"
		send(mypid, {:chooseSeqNum})
		receive do
			{pid, numSeq, :ok} -> # Se queda bloqueado esperando un signal (:ok) del proceso mutex
				send(mypid, {length(lista), :asignOutstandingReply})
				receive do
					{pid, :ok}
				end
				for node when node[1] != num <- lista do
					send(node[0], {num, numSeq, :request})
				end
		end
		receive do
			{pid, :ok_0} # Se espera a que haya una respuesta (:reply) del resto de nodos
		end
		for node <- lista do
			send(node[0], {mensaje, :mensaje}) # Al entrar a la seccion critica manda el mensaje a todos los nodos
		end
		send(mypid, {:release})
		receive do
			{pid, :ok}
		end
		for node <- lista do
			send(pid, {node[1], :checkDeferred})
			receive do
				{pid, value, :ok} ->
					if value do
						send(pid, {node[1], false, :modifyDeferred})
						receive do
							{pid, :ok}
						end
						send(node[0], {:reply}) # Mandar un mensaje de REPLY al nodo
					end
			end
		end
		distributed_critical_section(mypid, num, lista)
	end
	defp receive_request_messages(mypid, num) do
		receive do
			{node_pid, j, k, :request} ->
				send(mypid, {k, :maxSeq})
				receive do
					{pid, :ok}
				end
				send(mypid, {k, j, num, :checkDeferIt})
				receive do
					{pid, defer_it, :ok} ->
						if defer_it do
							send(pid, {j, true, :modifyDeferred})
							receive do
								{pid, :ok}
							end
						else
							send(node_pid, {:reply})
						end
				end
		end
		receive_request_messages(mypid, num)
	end

	defp receive_reply_messages(mypid) do
		receive do
			{pid, :reply}
		end
		send(mypid, {:subOutstandingReply})
		receive do
			{pid, :ok}
		end
		receive_reply_messages(mypid)
	end
	
	defp show_messages do
		receive do
			{pid, mensaje, :mensaje} ->
				IO.puts pid
				IO.puts mensaje
		end
		show_messages()
	end
end
