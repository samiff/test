/* eslint-disable eqeqeq */
import { check, sleep } from 'k6';
import http from 'k6/http';
import { sites } from './k6-shared.js';

export const options = {
	vus: 1,
    iterations: 1,
	thresholds: {
		checks: [
			{
				/**
				 * Fail if the number of failed checks is greater than 0.
				 * see: https://k6.io/docs/using-k6/thresholds/#fail-a-load-test-using-checks
				 */
				threshold: 'rate == 1.0',
			},
		],
	},
};

/**
 * Default test function.
 */
export default function () {
	/** Quick testing for Slack alert */
	const res = http.get('https://jetpack.com');
	check(res, {
		'Status is 500': (r) => r.status == 500,
	});
	sleep( 1 );;
	return;

	sites.forEach( site => {
		// Homepage.
		let res = http.get( site.url );
		check( res, {
			'status was 200': r => r.status == 200,
		} );

		// A random post.
		res = http.get( `${ site.url }/?random` );
		check( res, {
			'status was 200': r => r.status == 200,
		} );

		// Jetpack Blocks test post.
        if ( site.url !== 'https://jetpackedgeprivate.wpcomstaging.com' ) {
            res = http.get( `${ site.url }/2023/06/09/jetpack-blocks/` );
            check( res, {
                'status was 200': r => r.status == 200,
                'verify post end contents': r => r.body.includes( 'End of Jetpack Blocks post content' ),
            } );
        }
	} );

	sleep( 1 );
}