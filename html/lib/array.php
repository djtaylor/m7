<?php
$m7_lc_data = array (
		'post' => '98_126_154_27',
		'x' => array (
				'unit' => 'hop',
				'label' => 'Hops',
				'data' => array (
						'hops' => array (
								'label' => false,
								'values' => array (
										'1',
										'2',
										'3',
										'4',
										'5' 
								) 
						) 
				) 
		),
		'y' => array (
				'unit' => 'ms',
				'max' => '50',
				'label' => 'Time (ms)',
				'data' => array (
						'min_time' => array (
								'label' => 'Min. Time',
								'values' => array (
										'2',
										'5',
										'1',
										'10',
										'50' 
								) 
						),
						'avg_time' => array (
								'label' => 'Avg. Time',
								'values' => array (
										'2',
										'5',
										'1',
										'10',
										'50' 
								) 
						) 
				) 
		) 
);

$m7_results = array (
		'plans' => array (
				'plan' => array (
						'id' => null,
						'desc' => null,
						'cat' => array (
								'name' => 'net',
								'hosts' => array (
										'host' => array (
												'name' => null,
												'ip' => null,
												'lat' => null,
												'lon' => null,
												'region' => null,
												'destips' => array (
														'destip' => array (
																'ip' => null,
																'lat' => null,
																'lon' => null,
																'region' => null,
																'tests' => array (
																		'test' => array (
																				'type' => 'ping',
																				'runtimes' => array (
																						'runtime' => array (
																								'time' => null,
																								'properties' => array (
																										'pkt_loss' => null,
																										'min_time' => null,
																										'avg_time' => null,
																										'max_time' => null,
																										'avg_dev' => null 
																								) 
																						) 
																				) 
																		),
																		'test' => array (
																				'type' => 'traceroute',
																				'runtimes' => array (
																						'runtime' => array (
																								'time' => null,
																								'properties' => array (
																										'hops' => array (
																												'hop' => array (
																														'num' => '1',
																														'try' => '1',
																														'time' => null,
																														'ip' => array (
																																'val' => '111.111.111.111',
																																'lat' => null,
																																'lon' => null 
																														) 
																												) 
																										) 
																								) 
																						) 
																				) 
																		),
																		'test' => array (
																				'type' => 'mtr',
																				'runtimes' => array (
																						'runtime' => array (
																								'time' => null,
																								'properties' => array (
																										'hops' => array (
																												'hop' => array (
																														'num' => '1',
																														'pkt_loss' => null,
																														'min_time' => null,
																														'avg_time' => null,
																														'max_time' => null,
																														'avg_dev' => null,
																														'ips' => array (
																																'ip' => array (
																																		'val' => '111.111.111.111',
																																		'lat' => null,
																																		'lon' => null 
																																) 
																														) 
																												) 
																										) 
																								) 
																						) 
																				) 
																		) 
																) 
														) 
												) 
										) 
								) 
						) 
				) 
		) 
);

?>