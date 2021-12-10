type result = UpdateOk | QueryOk of int | QueryNotFound | Disconnect

val send_request : req:Client_data.client_req -> result Async.Deferred.t
